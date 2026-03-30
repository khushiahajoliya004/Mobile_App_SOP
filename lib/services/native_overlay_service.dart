import 'dart:io';
import 'package:flutter/services.dart';

/// NativeOverlayService: Controls the native Android floating button overlay
/// via Platform Channels.
///
/// The native FloatingButtonService provides:
/// - Draggable floating button across entire screen
/// - Edge snapping with smooth animation
/// - Visual recording state (blue idle, red pulsing when recording)
/// - Timer display during recording
/// - Tap to start/stop recording
/// - Always visible over other apps (SYSTEM_ALERT_WINDOW)
/// - Boundary constraints (won't go off screen)
class NativeOverlayService {
  static const _channel = MethodChannel('com.callrecorder/overlay');

  /// Whether native overlay is available (Android only).
  static bool get isAvailable => Platform.isAndroid;

  /// Check if the app has overlay (draw over other apps) permission.
  static Future<bool> hasOverlayPermission() async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod('hasOverlayPermission');
      return result == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Request overlay permission. Opens system settings on Android M+.
  static Future<void> requestOverlayPermission() async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on MissingPluginException {
      print('NativeOverlay: channel not available (overlay entry point?)');
    } catch (e) {
      print('NativeOverlay requestPermission error: $e');
    }
  }

  /// Show the floating button overlay.
  static Future<bool> showOverlay() async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod('showOverlay');
      return result == true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      print('NativeOverlay showOverlay error: $e');
      return false;
    }
  }

  /// Hide the floating button overlay.
  static Future<bool> hideOverlay() async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod('hideOverlay');
      return result == true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      print('NativeOverlay hideOverlay error: $e');
      return false;
    }
  }

  /// Update the overlay button's visual state.
  static Future<void> updateOverlayState({
    required bool recording,
    int seconds = 0,
  }) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('updateOverlayState', {
        'recording': recording,
        'seconds': seconds,
      });
    } catch (_) {}
  }
}
