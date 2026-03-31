import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../services/call_recorder_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class CallRecorderScreen extends StatefulWidget {
  const CallRecorderScreen({super.key});

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
  bool _isUploading = false;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  String? _statusMessage;
  bool _hasSop = false;
  bool _loading = true;

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
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showMessage('Microphone permission required');
      return;
    }

    final started = await _recorder.startRecording(audioSource: 'mic');
    if (started) {
      setState(() {
        _isRecording = true;
        _seconds = 0;
        _statusMessage = null;
      });
      _pulseController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } else {
      _showMessage('Failed to start recording');
    }
  }

  Future<void> _stopAndUpload() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _isUploading = true;
      _statusMessage = 'Uploading...';
    });

    final path = await _recorder.stopRecording();
    if (path == null) {
      setState(() {
        _isUploading = false;
        _statusMessage = 'Recording failed';
      });
      return;
    }

    if (_user == null || _user!.companyId == null) {
      setState(() {
        _isUploading = false;
        _statusMessage = 'User data missing. Please re-login.';
      });
      return;
    }

    try {
      final fileName = path.split('/').last;
      final response = await _api.createCall(
        customerName:
            'Call ${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        companyId: _user!.companyId!,
        userId: _user!.id,
        notes: 'Recorded from mobile app',
        audioFilePath: path,
        audioFileName: fileName,
      );

      final data = response.data;
      final callData = data is Map ? data['data'] : null;
      final analysisStatus = callData?['analysisStatus'] ?? '';

      if (mounted) {
        setState(() {
          _isUploading = false;
          _seconds = 0;
        });

        if (_user!.aiEnabled &&
            (analysisStatus == 'PENDING' || analysisStatus == 'PROCESSING')) {
          setState(() => _statusMessage = 'Uploaded! AI analysis started.');
          _showMessage('Call uploaded — AI analysis in progress');
        } else {
          setState(() => _statusMessage = 'Uploaded! Awaiting admin approval.');
          _showMessage('Call submitted for approval');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'Upload failed. Try again.';
        });
        _showMessage(
          'Upload failed: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}',
        );
      }
    }
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
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
                onTap: _isUploading
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
                                : _isUploading
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
                        child: _isUploading
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
                _isUploading
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
              if (!_isRecording && !_isUploading)
                Text(
                  _user!.aiEnabled
                      ? 'Recording will be analyzed by AI automatically'
                      : 'Recording will be sent for admin approval',
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
