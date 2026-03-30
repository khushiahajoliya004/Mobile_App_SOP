import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'native_recorder_service.dart';

/// CallRecorderService: Manages call recordings with native and Flutter fallback.
///
/// Recording strategy:
/// 1. Try native VOICE_COMMUNICATION (captures both sides on supported devices)
/// 2. Fallback to native VOICE_RECOGNITION
/// 3. Fallback to native MIC
/// 4. Final fallback to Flutter record plugin (MIC only)
///
/// Also provides:
/// - File listing with metadata (call type, duration, source)
/// - Permission management
/// - Device capability checking
class CallRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  bool _usingNative = false;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;
  bool get usingNative => _usingNative;

  /// Request all required permissions for call recording.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.phone,
      Permission.storage,
    ].request();

    final micOk = statuses[Permission.microphone]?.isGranted ?? false;
    return micOk;
  }

  /// Start recording using native engine with automatic fallback.
  Future<bool> startRecording({String audioSource = 'voice_communication'}) async {
    try {
      // Try native recording first
      final result = await NativeRecorderService.startRecording(
        audioSource: audioSource,
      );

      if (result != null) {
        _currentPath = result['path'] as String?;
        _isRecording = true;
        _usingNative = true;
        return true;
      }

      // Fallback to Flutter record plugin
      return await _startFlutterRecording();
    } catch (e) {
      print('CallRecorderService startRecording error: $e');
      // Final fallback
      return await _startFlutterRecording();
    }
  }

  /// Flutter-based recording fallback (MIC only).
  Future<bool> _startFlutterRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentPath = '${dir.path}/call_$timestamp.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentPath!,
        );
        _isRecording = true;
        _usingNative = false;
        return true;
      }
      return false;
    } catch (e) {
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the file path.
  Future<String?> stopRecording() async {
    try {
      if (_usingNative) {
        final result = await NativeRecorderService.stopRecording();
        _isRecording = false;
        _usingNative = false;
        return result?['path'] as String?;
      } else {
        final path = await _recorder.stop();
        _isRecording = false;
        return path;
      }
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  /// Get all recorded files sorted by most recent first.
  Future<List<FileSystemEntity>> getRecordedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) => f.path.endsWith('.m4a')).toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Get metadata for a recording file (from .meta.json sidecar).
  Future<Map<String, dynamic>?> getRecordingMetadata(String filePath) async {
    try {
      final metaFile = File('$filePath.meta.json');
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get device capabilities for call recording.
  Future<Map<String, dynamic>?> getDeviceCapabilities() async {
    return await NativeRecorderService.getDeviceCapabilities();
  }

  void dispose() {
    _recorder.dispose();
  }
}
