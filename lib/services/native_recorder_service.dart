import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// NativeRecorderService: Flutter interface to the native Kotlin CallRecorderEngine
/// via Platform Channels.
///
/// Supports:
/// - Starting/stopping recording with configurable audio source
/// - Querying recording state and device capabilities
/// - Automatic fallback from VOICE_COMMUNICATION -> VOICE_RECOGNITION -> MIC
///
/// Audio source priority for call recording:
/// - voice_communication: Best for capturing both sides (pre-Android 10)
/// - voice_recognition: Good quality, some devices capture call audio
/// - mic: Universal fallback, captures microphone only
///
/// VoIP/WhatsApp limitations:
/// - Only microphone audio can be captured for VoIP calls
/// - VoIP apps handle their own audio routing
/// - The recording will capture the user's voice and speaker leakage
class NativeRecorderService {
  static const _channel = MethodChannel('com.callrecorder/native_recorder');

  /// Start recording with the native engine.
  /// [audioSource]: "voice_communication", "voice_recognition", or "mic"
  /// Returns a map with {path, source, message} on success, null on failure.
  static Future<Map<String, dynamic>?> startRecording({
    String? path,
    String audioSource = 'voice_communication',
  }) async {
    try {
      final filePath = path ?? await _generatePath();
      final result = await _channel.invokeMethod('startRecording', {
        'path': filePath,
        'audioSource': audioSource,
      });
      return Map<String, dynamic>.from(result);
    } on MissingPluginException {
      print('NativeRecorder: channel not available');
      return null;
    } on PlatformException catch (e) {
      print('NativeRecorder startRecording error: ${e.message}');
      return null;
    }
  }

  /// Stop recording and return info about the completed recording.
  /// Returns {path, durationMs, source}.
  static Future<Map<String, dynamic>?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod('stopRecording');
      return Map<String, dynamic>.from(result);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      print('NativeRecorder stopRecording error: ${e.message}');
      return null;
    }
  }

  /// Check if currently recording.
  static Future<bool> isRecording() async {
    try {
      return await _channel.invokeMethod('isRecording') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get detailed recording info: {isRecording, path, source, durationMs}.
  static Future<Map<String, dynamic>?> getRecordingInfo() async {
    try {
      final result = await _channel.invokeMethod('getRecordingInfo');
      return Map<String, dynamic>.from(result);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get device capabilities for call recording.
  /// Returns {androidVersion, supportsVoiceCommunication, supportsCallCapture, manufacturer, model}.
  static Future<Map<String, dynamic>?> getDeviceCapabilities() async {
    try {
      final result = await _channel.invokeMethod('getDeviceCapabilities');
      return Map<String, dynamic>.from(result);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _generatePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/call_$ts.m4a';
  }
}
