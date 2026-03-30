import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Floating overlay button that controls recording via a command file.
/// The native CallRecorderService polls this file for commands.
class OverlayButton extends StatefulWidget {
  const OverlayButton({super.key});

  @override
  State<OverlayButton> createState() => _OverlayButtonState();
}

class _OverlayButtonState extends State<OverlayButton> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  Timer? _timer;
  int _seconds = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _onTap() async {
    debugPrint('OVERLAY TAP - isRecording: $_isRecording');
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<String> _getCommandFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/.recorder_command';
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final audioPath = '${dir.path}/call_$ts.m4a';

      final cmdPath = await _getCommandFilePath();
      debugPrint('OVERLAY: docs dir = ${dir.path}');
      debugPrint('OVERLAY: cmd file = $cmdPath');
      debugPrint('OVERLAY: audio path = $audioPath');
      await File(cmdPath).writeAsString('start|$audioPath');

      debugPrint('OVERLAY: Start command written for $audioPath');
      setState(() {
        _isRecording = true;
        _seconds = 0;
      });
      _pulseController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      debugPrint('OVERLAY: Start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final cmdPath = await _getCommandFilePath();
      await File(cmdPath).writeAsString('stop|');

      _timer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
      debugPrint('OVERLAY: Stop command written');
      setState(() {
        _isRecording = false;
        _seconds = 0;
      });
    } catch (e) {
      debugPrint('OVERLAY: Stop error: $e');
      _timer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
      setState(() {
        _isRecording = false;
        _seconds = 0;
      });
    }
  }

  String _formatTime(int totalSeconds) {
    final min = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: SizedBox(
          width: 140,
          height: 140,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isRecording ? _pulseAnim.value : 1.0,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isRecording
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : [const Color(0xFF1A73E8), const Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: _isRecording
                              ? const Color(0xFFEF4444).withOpacity(0.6)
                              : const Color(0xFF1A73E8).withOpacity(0.4),
                          blurRadius: 14,
                          spreadRadius: _isRecording ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        if (_isRecording)
                          Text(
                            _formatTime(_seconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
