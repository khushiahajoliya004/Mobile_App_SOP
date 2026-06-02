import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'native_recorder_service.dart';

/// CallRecorderService: Manages microphone recordings with crash protection.
///
/// CRASH FIXES IMPLEMENTED:
/// 1. Multiple recording prevention
/// 2. Permission validation before recording
/// 3. Safe file path handling
/// 4. Comprehensive error handling
/// 5. Proper recording state management
///
/// Recording strategy:
/// 1. Try native MIC (most compatible)
/// 2. Fallback to Flutter record plugin (MIC only)
class CallRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  bool _usingNative = false;
  bool _isInitializing = false; // CRASH FIX: Prevent race condition

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;
  bool get usingNative => _usingNative;

  /// CRASH FIX: Check if all required permissions are granted
  Future<bool> hasRequiredPermissions() async {
    try {
      // Check microphone permission
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        debugPrint('[Recorder] Microphone permission not granted');
        return false;
      }

      // Check notification permission for Android 13+
      if (Platform.isAndroid) {
        final notifStatus = await Permission.notification.status;
        debugPrint('[Recorder] Notification permission: $notifStatus');
      }

      return true;
    } catch (e) {
      debugPrint('[Recorder] Error checking permissions: $e');
      return false;
    }
  }

  /// Request all required permissions for recording
  Future<bool> requestPermissions() async {
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('[Recorder] Microphone permission denied');
        return false;
      }

      if (Platform.isAndroid) {
        // Required for call state detection (incoming/outgoing calls)
        await Permission.phone.request();
        // Required for Android 13+ notifications
        await Permission.notification.request();
      }

      return true;
    } catch (e) {
      debugPrint('[Recorder] Error requesting permissions: $e');
      return false;
    }
  }

  /// CRASH FIX: Start recording with crash protection and proper flow
  /// CRITICAL: This method enforces the correct sequence:
  /// 1. Check if already recording (prevent multiple instances)
  /// 2. Validate permissions
  /// 3. Generate safe file path
  /// 4. Start recording
  Future<bool> startRecording({
    String audioSource =
        'mic', // CRASH FIX: Changed default to 'mic' for compatibility
  }) async {
    // CRASH FIX: Prevent multiple recording instances
    if (_isRecording || _isInitializing) {
      debugPrint(
        '[Recorder] Already recording or initializing, ignoring start request',
      );
      return false;
    }

    _isInitializing = true;

    try {
      // CRASH FIX: Validate permissions before recording
      final hasPerms = await hasRequiredPermissions();
      if (!hasPerms) {
        debugPrint('[Recorder] Missing required permissions');
        _isInitializing = false;
        return false;
      }

      // CRASH FIX: Try native recording with 'mic' as default for maximum compatibility
      try {
        final result = await NativeRecorderService.startRecording(
          audioSource: 'mic', // Always use 'mic' for compatibility
        );

        if (result != null) {
          _currentPath = result['path'] as String?;
          if (_currentPath != null && _currentPath!.isNotEmpty) {
            _isRecording = true;
            _usingNative = true;
            _isInitializing = false;
            debugPrint('[Recorder] Native recording started: $_currentPath');
            return true;
          }
        }
      } catch (e) {
        debugPrint(
          '[Recorder] Native recording failed, trying Flutter fallback: $e',
        );
      }

      // Fallback to Flutter record plugin
      return await _startFlutterRecording();
    } catch (e) {
      debugPrint('[Recorder] startRecording error: $e');
      _isRecording = false;
      _isInitializing = false;
      return false;
    }
  }

  /// CRASH FIX: Flutter-based recording fallback with comprehensive error handling
  Future<bool> _startFlutterRecording() async {
    try {
      // CRASH FIX: Check permission again
      if (!await _recorder.hasPermission()) {
        debugPrint('[Recorder] Flutter recorder: no microphone permission');
        _isInitializing = false;
        return false;
      }

      // CRASH FIX: Generate safe file path
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/recording_$timestamp.m4a';

      // CRASH FIX: Validate path before use
      if (_currentPath == null || _currentPath!.isEmpty) {
        debugPrint('[Recorder] Failed to generate file path');
        _isInitializing = false;
        return false;
      }

      // CRASH FIX: Check if file can be created
      final file = File(_currentPath!);
      try {
        await file.create(recursive: true);
      } catch (e) {
        debugPrint('[Recorder] Cannot create file: $e');
        _isInitializing = false;
        return false;
      }

      // CRASH FIX: Start recording with error handling
      try {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 16000,
          ),
          path: _currentPath!,
        );
      } catch (e) {
        debugPrint('[Recorder] Flutter recorder start error: $e');
        _isInitializing = false;
        return false;
      }

      // CRASH FIX: Verify recording actually started
      await Future.delayed(const Duration(milliseconds: 300));
      final isActuallyRecording = await _recorder.isRecording();

      if (!isActuallyRecording) {
        debugPrint('[Recorder] Flutter recorder failed to start');
        _isInitializing = false;
        return false;
      }

      _isRecording = true;
      _usingNative = false;
      _isInitializing = false;
      debugPrint('[Recorder] Flutter recording started: $_currentPath');
      return true;
    } catch (e) {
      debugPrint('[Recorder] _startFlutterRecording error: $e');
      _isRecording = false;
      _isInitializing = false;
      return false;
    }
  }

  /// Stop recording and return the file path.
  /// CRASH FIX: Added comprehensive error handling
  Future<String?> stopRecording() async {
    // CRASH FIX: Check if actually recording
    if (!_isRecording) {
      debugPrint('[Recorder] Not recording, ignoring stop request');
      return null;
    }

    try {
      if (_usingNative) {
        final result = await NativeRecorderService.stopRecording();
        _isRecording = false;
        _usingNative = false;

        if (result == null) {
          debugPrint('[Recorder] Native stopRecording returned null');
          return null;
        }

        final path = result['path'] as String?;
        debugPrint('[Recorder] Native recording stopped: $path');
        return path;
      } else {
        // CRASH FIX: Safe stop with error handling
        String? path;
        try {
          path = await _recorder.stop();
        } catch (e) {
          debugPrint('[Recorder] Flutter recorder stop error: $e');
        }

        _isRecording = false;
        debugPrint('[Recorder] Flutter recording stopped: $path');
        return path;
      }
    } catch (e) {
      debugPrint('[Recorder] stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Get all recorded files sorted by most recent first.
  /// CRASH FIX: Added error handling
  Future<List<FileSystemEntity>> getRecordedFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        return [];
      }

      final files = dir
          .listSync()
          .where((f) => f.path.endsWith('.m4a'))
          .toList();

      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      return files;
    } catch (e) {
      debugPrint('[Recorder] getRecordedFiles error: $e');
      return [];
    }
  }

  /// Get metadata for a recording file (from .meta.json sidecar).
  Future<Map<String, dynamic>?> getRecordingMetadata(String filePath) async {
    try {
      final metaFile = File('$filePath.meta.json');
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Recorder] getRecordingMetadata error: $e');
    }
    return null;
  }

  /// Get device capabilities for recording.
  Future<Map<String, dynamic>?> getDeviceCapabilities() async {
    return await NativeRecorderService.getDeviceCapabilities();
  }

  /// Dispose resources safely
  void dispose() {
    try {
      _recorder.dispose();
    } catch (e) {
      debugPrint('[Recorder] dispose error: $e');
    }
  }
}
