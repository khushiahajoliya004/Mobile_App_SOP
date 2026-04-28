import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../services/call_recorder_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/foreground_service.dart';
import '../models/user_model.dart';

class CallRecorderScreen extends StatefulWidget {
  final String? leadId;
  final String? leadCustomerName;

  const CallRecorderScreen({super.key, this.leadId, this.leadCustomerName});

  @override
  State<CallRecorderScreen> createState() => _CallRecorderScreenState();
}

class _CallRecorderScreenState extends State<CallRecorderScreen>
    with SingleTickerProviderStateMixin {
  final _recorder = CallRecorderService();
  final _api = ApiService();
  final _auth = AuthService();

  UserModel? _user;
  bool _isRecording = false;
  bool _isSaving = false;
  bool _isStarting = false; // CRASH FIX: Prevent multiple start requests
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  String? _statusMessage;
  bool _hasSop = false;
  bool _loading = true;

  // SOP-resolved fields (fetched on load)
  String? _sopCategoryId;
  String? _sopSalesStageId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getUser();
    if (mounted) {
      setState(() {
        _user = user;
        _hasSop = user?.sopId != null && user!.sopId!.isNotEmpty;
        _loading = false;
      });
    }

    // Fetch SOP details (categoryId + salesStageId) in background
    if (user?.sopId != null && user!.sopId!.isNotEmpty) {
      try {
        final res = await _api.getMySop();
        final sopData = res.data is Map ? res.data['data'] : null;
        if (sopData != null && mounted) {
          setState(() {
            _sopCategoryId = sopData['categoryId'];
            _sopSalesStageId = sopData['salesStageId'];
          });
        }
      } catch (_) {
        // Non-fatal — backend auto-resolves from SOP if not provided
      }
    }
  }

  /// CRASH FIX: Correct recording flow with proper sequence
  /// Flow: Check permissions -> Start foreground service -> Wait -> Start recording
  Future<void> _startRecording() async {
    // CRASH FIX: Prevent multiple start requests
    if (_isStarting || _isRecording) {
      debugPrint('[Recorder] Already starting or recording');
      return;
    }

    _isStarting = true;

    try {
      // STEP 1: Check and request microphone permission
      debugPrint('[Recorder] Step 1: Checking microphone permission...');
      final micStatus = await Permission.microphone.status;

      if (!micStatus.isGranted) {
        debugPrint('[Recorder] Requesting microphone permission...');
        final requested = await Permission.microphone.request();

        if (!requested.isGranted) {
          _isStarting = false;
          _showMessage('Microphone permission required');

          // Handle permanently denied
          if (requested.isPermanentlyDenied) {
            _showPermissionSettingsDialog('Microphone');
          }
          return;
        }
      }

      // STEP 2: Check notification permission (Android 13+)
      debugPrint('[Recorder] Step 2: Checking notification permission...');
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
        // Continue even if denied - notification is optional
      }

      // STEP 3: Start foreground service FIRST
      debugPrint('[Recorder] Step 3: Starting foreground service...');
      try {
        final serviceStarted = await ForegroundServiceManager.startService();
        if (!serviceStarted) {
          debugPrint(
            '[Recorder] Warning: Foreground service may not have started',
          );
          // Continue anyway - recording might still work
        }
      } catch (e) {
        debugPrint('[Recorder] Foreground service error: $e');
        // Continue - recording might still work without foreground service
      }

      // STEP 4: CRITICAL - Wait for service to stabilize
      debugPrint('[Recorder] Step 4: Waiting for service to stabilize...');
      await Future.delayed(const Duration(milliseconds: 800));

      // STEP 5: Start recording
      debugPrint('[Recorder] Step 5: Starting audio recording...');
      final started = await _recorder.startRecording(
        audioSource: 'mic', // CRASH FIX: Use 'mic' for maximum compatibility
      );

      if (!started) {
        debugPrint('[Recorder] Failed to start recording');
        _isStarting = false;

        // Stop foreground service if recording failed
        try {
          await ForegroundServiceManager.stopService();
        } catch (_) {}

        _showMessage('Failed to start recording. Please check permissions.');
        return;
      }

      debugPrint('[Recorder] Recording started successfully');

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isStarting = false;
          _seconds = 0;
          _statusMessage = null;
        });
        _pulseController.repeat(reverse: true);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      }
    } catch (e) {
      debugPrint('[Recorder] Start recording error: $e');
      _isStarting = false;
      _isRecording = false;

      // Clean up
      try {
        await ForegroundServiceManager.stopService();
      } catch (_) {}

      _showMessage('Error starting recording: ${e.toString()}');
    }
  }

  /// Stop recording with proper cleanup
  Future<void> _stopAndUpload() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _isSaving = true;
      _statusMessage = 'Uploading...';
    });

    // STEP 1: Stop recording
    debugPrint('[Recorder] Stopping recording...');
    final path = await _recorder.stopRecording();
    debugPrint('[Recorder] Stop result: $path');

    // STEP 2: Stop foreground service
    debugPrint('[Recorder] Stopping foreground service...');
    try {
      await ForegroundServiceManager.stopService();
    } catch (e) {
      debugPrint('[Recorder] Error stopping service: $e');
    }

    // Handle missing path
    if (path == null || path.isEmpty) {
      // Try to find the most recent recording
      try {
        final files = await _recorder.getRecordedFiles();
        if (files.isNotEmpty) {
          final mostRecent = files.first.path;
          debugPrint('[Recorder] Using most recent file: $mostRecent');
          await _uploadRecording(mostRecent);
          return;
        }
      } catch (e) {
        debugPrint('[Recorder] Error finding recent file: $e');
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Recording failed to save';
        });
      }
      return;
    }

    await _uploadRecording(path);
  }

  Future<void> _uploadRecording(String path) async {
    if (_user == null || _user!.companyId == null) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'User data missing. Please re-login.';
      });
      return;
    }

    try {
      final now = DateTime.now();
      final fileName = path.split('/').last;
      final response = await _api.createCall(
        customerName:
            widget.leadCustomerName ??
            'Call ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        companyId: _user!.companyId!,
        userId: _user!.id,
        categoryId: _sopCategoryId,
        salesStageId: _sopSalesStageId,
        notes: 'Recorded from mobile app',
        audioFilePath: path,
        audioFileName: fileName,
      );

      if (mounted) {
        final callData = response.data is Map ? response.data['data'] : null;
        final callId = callData?['id']?.toString();
        final analysisStatus = callData?['analysisStatus'] ?? '';

        if (widget.leadId != null && callId != null) {
          await _api.createLeadActivity(
            leadId: widget.leadId!,
            type: 'CALL',
            callId: callId,
            notes: 'Recording completed from mobile app',
          );
        }

        // aiEnabled=true → PENDING/PROCESSING (direct AI analysis)
        // aiEnabled=false → APPROVAL_PENDING (admin must approve first)
        final isAiFlow =
            _user!.aiEnabled &&
            (analysisStatus == 'PENDING' || analysisStatus == 'PROCESSING');

        final msg = isAiFlow
            ? 'Uploaded! AI analysis started.'
            : 'Submitted for admin approval.';

        setState(() {
          _isSaving = false;
          _seconds = 0;
          _statusMessage = msg;
        });
        _showMessage(msg, success: true);
        if (widget.leadId != null) {
          _showPostRecordingFlow();
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Upload failed. Try again.';
        if (e is DioException) {
          final serverMsg = e.response?.data?['message'];
          if (serverMsg != null) {
            errorMsg = serverMsg is List
                ? serverMsg.join(', ')
                : serverMsg.toString();
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            errorMsg = 'Connection timed out. Check your internet.';
          } else if (e.type == DioExceptionType.connectionError) {
            errorMsg = 'No internet connection.';
          }
        }
        debugPrint('[Recorder] Upload error: $e');
        setState(() {
          _isSaving = false;
          _statusMessage = errorMsg;
        });
        _showMessage(errorMsg);
      }
    }
  }

  void _showMessage(String msg, {bool success = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : null,
        ),
      );
    }
  }

  Future<void> _showPostRecordingFlow() async {
    DateTime selected = DateTime.now().add(const Duration(days: 1));
    final remarkController = TextEditingController();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Next Step', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: remarkController, decoration: const InputDecoration(labelText: 'Remark')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: selected,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  if (!ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selected));
                  if (time == null) return;
                  setSheetState(() {
                    selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  });
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Follow-up: ${selected.day}/${selected.month} ${selected.hour}:${selected.minute.toString().padLeft(2, '0')}'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await _api.updateLeadStatus(widget.leadId!, {
                    'nextFollowUpAt': selected.toUtc().toIso8601String(),
                  });
                  if (remarkController.text.trim().isNotEmpty) {
                    await _api.createLeadActivity(
                      leadId: widget.leadId!,
                      type: 'NOTE',
                      notes: remarkController.text.trim(),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMessage('Follow-up scheduled', success: true);
                },
                child: const Text('Schedule Follow-up'),
              ),
              TextButton(
                onPressed: () async {
                  await _api.updateLeadStatus(widget.leadId!, {
                    'status': 'LOST',
                    'lostReason': remarkController.text.trim().isEmpty ? 'Marked lost from mobile app' : remarkController.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMessage('Lead marked lost', success: true);
                },
                child: const Text('Mark Lost'),
              ),
            ],
          ),
        ),
      ),
    );
    remarkController.dispose();
  }

  /// CRASH FIX: Show permission settings dialog for permanently denied permissions
  void _showPermissionSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission is permanently denied. '
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    // Stop foreground service if still running
    if (_isRecording) {
      ForegroundServiceManager.stopService();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    // No SOP assigned — show message
    if (!_hasSop) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_late_rounded,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SOP Not Assigned',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please ask your admin to assign an SOP before recording calls.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.scaffoldBg, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AI badge
              if (widget.leadCustomerName != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.leadCustomerName!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _user!.aiEnabled
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _user!.aiEnabled
                          ? Icons.auto_awesome
                          : Icons.edit_note_rounded,
                      size: 16,
                      color: _user!.aiEnabled
                          ? AppColors.primary
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _user!.aiEnabled
                          ? 'AI Analysis Enabled'
                          : 'Manual Review Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _user!.aiEnabled
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Record button with pulse animation
              GestureDetector(
                onTap: _isSaving
                    ? null
                    : (_isRecording ? _stopAndUpload : _startRecording),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = _isRecording
                        ? 1.0 + (_pulseController.value * 0.08)
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isRecording
                                ? [AppColors.error, const Color(0xFFDC2626)]
                                : _isSaving
                                ? [AppColors.warning, const Color(0xFFF59E0B)]
                                : [AppColors.primary, AppColors.gradientEnd],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isRecording
                                          ? AppColors.error
                                          : AppColors.primary)
                                      .withOpacity(0.3),
                              blurRadius: _isRecording ? 30 : 20,
                              spreadRadius: _isRecording ? 4 : 0,
                            ),
                          ],
                        ),
                        child: _isSaving
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 64,
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Timer
              if (_isRecording)
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),

              const SizedBox(height: 12),

              // Label
              Text(
                _isSaving
                    ? 'Uploading...'
                    : _isRecording
                    ? 'Tap to stop & upload'
                    : 'Tap to start recording',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isRecording
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),

              // Status message
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _statusMessage!.contains('failed')
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusMessage!.contains('failed')
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 18,
                        color: _statusMessage!.contains('failed')
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _statusMessage!.contains('failed')
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Info text
              if (!_isRecording && !_isSaving)
                Text(
                  _user!.aiEnabled
                      ? 'Stop recording → auto AI analysis'
                      : 'Stop recording → sent for admin approval',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
