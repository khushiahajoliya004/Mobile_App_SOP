import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/call_recorder_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/foreground_service.dart';
import '../models/user_model.dart';

class CallRecorderScreen extends StatefulWidget {
  final String? leadId;
  final String? dealId;
  final String? leadCustomerName;
  final String? leadPhone;
  const CallRecorderScreen({
    super.key,
    this.leadId,
    this.dealId,
    this.leadCustomerName,
    this.leadPhone,
  });
  @override
  State<CallRecorderScreen> createState() => _CallRecorderScreenState();
}

class _CallRecorderScreenState extends State<CallRecorderScreen>
    with TickerProviderStateMixin {
  final _recorder = CallRecorderService();
  final _api = ApiService();
  final _auth = AuthService();

  UserModel? _user;
  bool _isRecording = false;
  bool _isSaving = false;
  bool _isStarting = false;
  int _seconds = 0;
  Timer? _timer;
  String? _statusMessage;
  bool _hasSop = false;
  bool _loading = true;
  int _localCount = 0;
  String? _sopCategoryId;
  String? _sopSalesStageId;

  late AnimationController _orbCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _loadUser();
  }

  // ═══ BUSINESS LOGIC (unchanged) ═══════════════════════════════════════════
  Future<void> _loadUser() async {
    final user = await _auth.getUser();
    final prefs = await SharedPreferences.getInstance();
    final localList = prefs.getStringList('local_recordings') ?? [];
    if (mounted)
      setState(() {
        _user = user;
        _hasSop = user?.sopId != null && user!.sopId!.isNotEmpty;
        _localCount = localList.length;
        _loading = false;
      });
    if (user?.sopId != null && user!.sopId!.isNotEmpty) {
      try {
        final res = await _api.getMySop();
        final d = res.data is Map ? res.data['data'] : null;
        if (d != null && mounted)
          setState(() {
            _sopCategoryId = d['categoryId'];
            _sopSalesStageId = d['salesStageId'];
          });
      } catch (_) {}
    }
  }

  Future<void> _startRecording() async {
    if (_isStarting || _isRecording) return;
    _isStarting = true;
    try {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final r = await Permission.microphone.request();
        if (!r.isGranted) {
          _isStarting = false;
          _showMsg('Microphone permission required');
          if (r.isPermanentlyDenied) _showPermDialog();
          return;
        }
      }
      final n = await Permission.notification.status;
      if (!n.isGranted) {
        await Permission.notification.request();
      }
      try {
        await ForegroundServiceManager.startService();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
      final started = await _recorder.startRecording(audioSource: 'mic');
      if (!started) {
        _isStarting = false;
        try {
          await ForegroundServiceManager.stopService();
        } catch (_) {}
        _showMsg('Failed to start recording');
        return;
      }
      if (mounted) {
        setState(() {
          _isRecording = true;
          _isStarting = false;
          _seconds = 0;
          _statusMessage = null;
        });
        _pulseCtrl.repeat(reverse: true);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      }
    } catch (e) {
      _isStarting = false;
      _isRecording = false;
      try {
        await ForegroundServiceManager.stopService();
      } catch (_) {}
      _showMsg('Error: $e');
    }
  }

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() {
      _isRecording = false;
      _isSaving = true;
      _statusMessage = 'Processing...';
    });
    final path = await _recorder.stopRecording();
    try {
      await ForegroundServiceManager.stopService();
    } catch (_) {}
    if (path == null || path.isEmpty) {
      try {
        final f = await _recorder.getRecordedFiles();
        if (f.isNotEmpty) {
          await _processRecording(f.first.path);
          return;
        }
      } catch (_) {}
      if (mounted)
        setState(() {
          _isSaving = false;
          _statusMessage = 'Recording failed';
        });
      return;
    }
    await _processRecording(path);
  }

  Future<void> _processRecording(String path) async {
    if (!_hasSop) {
      await _saveLocally(path);
      return;
    }
    await _uploadRecording(path);
  }

  Future<void> _saveLocally(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('local_recordings') ?? [];
      final now = DateTime.now();
      list.add(
        jsonEncode({
          'path': filePath,
          'name':
              widget.leadCustomerName ??
              'Call ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, "0")}',
          'date': now.toIso8601String(),
          'duration': _seconds,
          'leadId': widget.leadId,
        }),
      );
      await prefs.setStringList('local_recordings', list);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _seconds = 0;
          _localCount = list.length;
          _statusMessage = 'Saved locally';
        });
        _showMsg('Recording saved locally', success: true);
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _isSaving = false;
          _statusMessage = 'Save failed';
        });
    }
  }

  Future<void> _uploadRecording(String path) async {
    setState(() => _statusMessage = 'Uploading...');
    if (_user == null || _user!.companyId == null) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'User data missing';
      });
      return;
    }
    try {
      final now = DateTime.now();
      final fn = path.split('/').last;
      final res = await _api.createCall(
        customerName:
            widget.leadCustomerName ??
            'Call ${now.day}/${now.month} ${now.hour}:${now.minute.toString().padLeft(2, "0")}',
        companyId: _user!.companyId!,
        userId: _user!.id,
        categoryId: _sopCategoryId,
        salesStageId: _sopSalesStageId,
        notes: 'Recorded from mobile',
        audioFilePath: path,
        audioFileName: fn,
        leadId: widget.leadId,
        dealId: widget.dealId,
      );
      if (mounted) {
        final cd = res.data is Map ? res.data['data'] : null;
        final cid = cd?['id']?.toString();
        final as2 = cd?['analysisStatus'] ?? '';
        if (widget.leadId != null && cid != null) {
          try {
            await _api.createLeadActivity(
              leadId: widget.leadId!,
              type: 'CALL',
              callId: cid,
              notes: 'Recording from mobile',
            );
          } catch (_) {}
        }
        final isAi =
            _user!.aiEnabled && (as2 == 'PENDING' || as2 == 'PROCESSING');
        final msg = isAi
            ? 'Uploaded! Analysis started.'
            : 'Submitted for approval.';
        setState(() {
          _isSaving = false;
          _seconds = 0;
          _statusMessage = msg;
        });
        _showMsg(msg, success: true);
        if (widget.leadId != null) _showPostRecordingFlow();
      }
    } catch (e) {
      if (mounted) {
        String err = 'Upload failed';
        if (e is DioException) {
          var data = e.response?.data;
          final statusCode = e.response?.statusCode;

          // If data is a JSON string, try to parse it
          if (data is String && data.startsWith('{')) {
            try {
              data = jsonDecode(data);
            } catch (_) {}
          }

          // Extract real error message from backend response
          if (data is Map) {
            final msg = data['message'];
            if (msg is List && msg.isNotEmpty) {
              err = msg.join(', ');
            } else if (msg is String && msg.isNotEmpty) {
              err = msg;
            } else if (data['error'] is String &&
                data['error'] != 'Bad Request') {
              err = data['error'];
            }
          } else if (data is String && data.isNotEmpty) {
            err = data;
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            err = 'Connection timed out. Check your internet.';
          } else if (e.type == DioExceptionType.connectionError) {
            err = 'Cannot connect to server. Check your internet.';
          } else if (e.type == DioExceptionType.badCertificate) {
            err = 'Server certificate expired. Contact support.';
          } else if (statusCode != null) {
            switch (statusCode) {
              case 400:
                err = 'Invalid request.';
                break;
              case 401:
                err = 'Session expired. Please login again.';
                break;
              case 403:
                err = 'Permission denied.';
                break;
              case 413:
                err = 'File too large.';
                break;
              case 500:
                err = 'Server error. Try again later.';
                break;
              default:
                err = 'Upload failed (Error $statusCode)';
            }
          }
        }
        setState(() {
          _isSaving = false;
          _statusMessage = err;
        });
        _showMsg(err);
      }
    }
  }

  Future<void> _uploadLocalRecordings() async {
    if (!_hasSop || _user == null || _user!.companyId == null) {
      _showMsg('SOP must be assigned first');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('local_recordings') ?? [];
    if (list.isEmpty) {
      _showMsg('No local recordings');
      return;
    }
    setState(() => _isSaving = true);
    int ok = 0, fail = 0;
    String? lastError;
    for (int i = 0; i < list.length; i++) {
      try {
        final e = jsonDecode(list[i]) as Map<String, dynamic>;
        final fp = e['path'] as String;
        if (!await File(fp).exists()) {
          fail++;
          lastError = 'File not found';
          continue;
        }
        setState(() => _statusMessage = 'Uploading ${i + 1}/${list.length}...');
        await _api.createCall(
          customerName: e['name'] ?? 'Local',
          companyId: _user!.companyId!,
          userId: _user!.id,
          categoryId: _sopCategoryId,
          salesStageId: _sopSalesStageId,
          notes: 'From local',
          audioFilePath: fp,
          audioFileName: fp.split('/').last,
        );
        ok++;
      } catch (uploadErr) {
        fail++;
        if (uploadErr is DioException) {
          final data = uploadErr.response?.data;
          if (data is Map && data['message'] is String) {
            lastError = data['message'];
          } else if (uploadErr.type == DioExceptionType.connectionTimeout ||
              uploadErr.type == DioExceptionType.sendTimeout) {
            lastError = 'Upload timed out';
          } else {
            lastError =
                'Server error (${uploadErr.response?.statusCode ?? 'no response'})';
          }
        } else {
          lastError = uploadErr.toString();
        }
      }
    }
    await prefs.setStringList('local_recordings', []);
    if (mounted) {
      setState(() {
        _localCount = 0;
        _isSaving = false;
        _statusMessage = null;
      });
      final msg = fail > 0 && lastError != null
          ? 'Uploaded $ok, failed $fail: $lastError'
          : 'Uploaded $ok, failed $fail';
      _showMsg(msg, success: ok > 0 && fail == 0);
    }
  }

  void _showMsg(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppColors.success : const Color(0xFF334155),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showPostRecordingFlow() async {
    DateTime sel = DateTime.now().add(const Duration(days: 1));
    final rc = TextEditingController();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Next Step',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rc,
                decoration: const InputDecoration(labelText: 'Remark'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: sel,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(sel),
                  );
                  if (t == null) return;
                  ss(() {
                    sel = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                  });
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  'Follow-up: ${sel.day}/${sel.month} ${sel.hour}:${sel.minute.toString().padLeft(2, "0")}',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await _api.updateLeadStatus(widget.leadId!, {
                    'nextFollowUpAt': sel.toUtc().toIso8601String(),
                  });
                  if (rc.text.trim().isNotEmpty)
                    await _api.createLeadActivity(
                      leadId: widget.leadId!,
                      type: 'NOTE',
                      notes: rc.text.trim(),
                    );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMsg('Follow-up scheduled', success: true);
                },
                child: const Text('Schedule Follow-up'),
              ),
              TextButton(
                onPressed: () async {
                  await _api.updateLeadStatus(widget.leadId!, {
                    'status': 'LOST',
                    'lostReason': rc.text.trim().isEmpty
                        ? 'Marked lost'
                        : rc.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMsg('Lead marked lost', success: true);
                },
                child: const Text('Mark Lost'),
              ),
            ],
          ),
        ),
      ),
    );
    rc.dispose();
  }

  void _showPermDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Permission Required'),
        content: const Text(
          'Microphone permission is permanently denied. Enable it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Settings'),
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

  bool get _isError =>
      _statusMessage != null &&
      (_statusMessage!.contains('failed') ||
          _statusMessage!.contains('Failed') ||
          _statusMessage!.contains('Error') ||
          _statusMessage!.contains('not found') ||
          _statusMessage!.contains('Not found'));

  @override
  void dispose() {
    _timer?.cancel();
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _recorder.dispose();
    if (_isRecording) ForegroundServiceManager.stopService();
    super.dispose();
  }

  // ═══ UI BUILD ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Container(
        color: const Color(0xFF080C18),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF818CF8),
            strokeWidth: 2,
          ),
        ),
      );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF050810),
            Color(0xFF0C1024),
            Color(0xFF101838),
            Color(0xFF080C18),
          ],
          stops: [0.0, 0.25, 0.65, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  // Status text
                  Expanded(
                    child: Text(
                      _isRecording
                          ? 'Recording in progress'
                          : 'Ready to capture',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isRecording
                            ? const Color(0xFF22D3EE)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  // Mode chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _user!.aiEnabled
                              ? Icons.auto_awesome
                              : Icons.edit_note_rounded,
                          size: 12,
                          color: const Color(0xFF818CF8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _user!.aiEnabled ? 'AI' : 'Manual',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Banners
            if (!_hasSop)
              _banner(
                Icons.info_outline_rounded,
                'No SOP — recordings saved locally',
                const Color(0xFFF59E0B),
              ),
            if (_localCount > 0) _localBanner(),
            if (widget.leadCustomerName != null)
              _banner(
                Icons.person_rounded,
                (widget.leadPhone != null && widget.leadPhone!.isNotEmpty)
                    ? '${widget.leadCustomerName!}  •  ${widget.leadPhone!}'
                    : widget.leadCustomerName!,
                const Color(0xFF818CF8),
              ),

            // Main orb area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Orb
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _orbCtrl,
                          _pulseCtrl,
                          _glowCtrl,
                        ]),
                        builder: (_, __) => CustomPaint(
                          painter: _OrbPainter(
                            orbPhase: _orbCtrl.value,
                            pulseValue: _isRecording ? _pulseCtrl.value : 0,
                            glowValue: _glowCtrl.value,
                            isRecording: _isRecording,
                            isSaving: _isSaving,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),

                    // Timer or text
                    if (_isRecording) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w200,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap stop to finish',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ] else if (_isSaving) ...[
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage ?? 'Processing...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to start recording',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasSop
                            ? 'Audio will be analyzed automatically'
                            : 'Audio will be saved locally',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],

                    // Status message
                    if (_statusMessage != null && !_isSaving) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _isError
                              ? const Color(0x20EF4444)
                              : const Color(0x2010B981),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isError
                                ? const Color(0x40EF4444)
                                : const Color(0x4010B981),
                          ),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isError
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _glassBtn(Icons.play_arrow_rounded, 46),
                  // Main record button
                  GestureDetector(
                    onTap: _isSaving
                        ? null
                        : (_isRecording ? _stopAndProcess : _startRecording),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isRecording
                              ? [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFDC2626),
                                ]
                              : _isSaving
                              ? [
                                  const Color(0xFFF59E0B),
                                  const Color(0xFFD97706),
                                ]
                              : [
                                  const Color(0xFF6366F1),
                                  const Color(0xFF8B5CF6),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isRecording
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF6366F1))
                                    .withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isSaving
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                    ),
                  ),
                  _glassBtn(Icons.headphones_rounded, 46),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _localBanner() {
    return GestureDetector(
      onTap: _hasSop && !_isSaving ? _uploadLocalRecordings : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (_hasSop ? const Color(0xFF10B981) : const Color(0xFF6366F1))
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (_hasSop ? const Color(0xFF10B981) : const Color(0xFF6366F1))
                .withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_upload_rounded,
              size: 16,
              color: _hasSop
                  ? const Color(0xFF10B981)
                  : const Color(0xFF818CF8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_localCount local${_hasSop ? " — tap to upload" : " saved"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hasSop
                      ? const Color(0xFF10B981)
                      : const Color(0xFF818CF8),
                ),
              ),
            ),
            if (_hasSop)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glassBtn(IconData icon, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.4),
        size: size * 0.45,
      ),
    );
  }
}

// ═══ 3D ORB PAINTER ═════════════════════════════════════════════════════════
class _OrbPainter extends CustomPainter {
  final double orbPhase, pulseValue, glowValue;
  final bool isRecording, isSaving;
  _OrbPainter({
    required this.orbPhase,
    required this.pulseValue,
    required this.glowValue,
    required this.isRecording,
    required this.isSaving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final center = Offset(cx, cy);
    final baseR = size.width * 0.33;
    final phase = orbPhase * 2 * math.pi;

    // Outer glow
    canvas.drawCircle(
      center,
      baseR + 35,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45)
        ..color =
            (isRecording ? const Color(0xFF06B6D4) : const Color(0xFF6366F1))
                .withValues(alpha: 0.12 + glowValue * 0.06),
    );

    // Inner glow
    canvas.drawCircle(
      center,
      baseR + 10,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..color =
            (isRecording ? const Color(0xFF22D3EE) : const Color(0xFF818CF8))
                .withValues(
                  alpha:
                      0.08 +
                      (isRecording ? pulseValue * 0.08 : glowValue * 0.04),
                ),
    );

    // Horizontal rings
    for (int r = 0; r < 14; r++) {
      final rp = r / 14;
      final rPhase = phase + rp * math.pi;
      final path = Path();
      for (int i = 0; i <= 64; i++) {
        final a = (i / 64) * 2 * math.pi;
        double rad = baseR;
        if (isRecording) {
          rad += math.sin(a * 3 + rPhase * 2) * 14 * (0.4 + pulseValue * 0.6);
          rad += math.cos(a * 5 + rPhase * 3) * 8 * pulseValue;
        } else {
          rad += math.sin(a * 3 + rPhase) * 5 * (0.8 + glowValue * 0.2);
          rad += math.cos(a * 5 + rPhase * 0.7) * 3;
        }
        final tilt = math.sin(rp * math.pi) * 0.92;
        final x = cx + math.cos(a) * rad;
        final y = cy + math.sin(a) * rad * tilt;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final alpha =
          (0.06 + rp * 0.14) *
          (isRecording ? (0.6 + pulseValue * 0.4) : (0.5 + glowValue * 0.25));
      final c = isRecording
          ? Color.lerp(const Color(0xFF06B6D4), const Color(0xFFEC4899), rp)!
          : isSaving
          ? Color.lerp(const Color(0xFFF59E0B), const Color(0xFF6366F1), rp)!
          : Color.lerp(const Color(0xFF06B6D4), const Color(0xFF6366F1), rp)!;
      canvas.drawPath(
        path,
        Paint()
          ..color = c.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isRecording ? 1.4 : 0.9,
      );
    }

    // Vertical rings
    for (int r = 0; r < 8; r++) {
      final rp = r / 8;
      final rPhase = phase + rp * math.pi;
      final path = Path();
      for (int i = 0; i <= 64; i++) {
        final a = (i / 64) * 2 * math.pi;
        double rad = baseR;
        if (isRecording) {
          rad += math.cos(a * 4 + rPhase * 2.5) * 10 * (0.4 + pulseValue * 0.6);
        } else {
          rad += math.cos(a * 4 + rPhase * 0.5) * 4;
        }
        final tilt = math.sin(rp * math.pi) * 0.92;
        final x = cx + math.cos(a) * rad * tilt;
        final y = cy + math.sin(a) * rad;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final alpha =
          (0.04 + rp * 0.08) * (isRecording ? (0.5 + pulseValue * 0.5) : 0.4);
      final c = isRecording ? const Color(0xFF22D3EE) : const Color(0xFF818CF8);
      canvas.drawPath(
        path,
        Paint()
          ..color = c.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }

    // Surface dots
    final rng = math.Random(42);
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotCount = isRecording ? 90 : 55;
    for (int i = 0; i < dotCount; i++) {
      final theta = rng.nextDouble() * 2 * math.pi;
      final phi = rng.nextDouble() * math.pi;
      double rad = baseR * 0.96;
      if (isRecording) {
        rad += math.sin(theta * 3 + phase) * 8 * (0.4 + pulseValue * 0.6);
      } else {
        rad += math.sin(theta * 3 + phase) * 3;
      }
      final x = cx + rad * math.sin(phi) * math.cos(theta + phase * 0.3);
      final y = cy + rad * math.cos(phi);
      final depth = math.sin(phi) * math.sin(theta + phase * 0.3);
      final da = (0.15 + depth * 0.5).clamp(0.03, 0.65);
      final c = isRecording
          ? Color.lerp(
              const Color(0xFF06B6D4),
              const Color(0xFFEC4899),
              rng.nextDouble(),
            )!
          : Color.lerp(
              const Color(0xFF6366F1),
              const Color(0xFF06B6D4),
              rng.nextDouble(),
            )!;
      dotPaint.color = c.withValues(
        alpha:
            da *
            (isRecording ? (0.4 + pulseValue * 0.6) : (0.3 + glowValue * 0.35)),
      );
      canvas.drawCircle(Offset(x, y), isRecording ? 1.6 : 1.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}
