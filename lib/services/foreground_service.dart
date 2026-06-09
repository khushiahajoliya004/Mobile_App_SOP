import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart'
    hide NotificationVisibility;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_overlay_service.dart';

/// Foreground task callback entry point.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SimpleTaskHandler());
}

class SimpleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp) async {}
  @override
  void onReceiveData(Object data) {}
}

/// ForegroundServiceManager: Manages the Flutter foreground task and overlay.
///
/// This works alongside the native CallMonitorService and FloatingButtonService.
/// The Flutter foreground task keeps the app alive in the background,
/// while native services handle actual call detection and recording.
class ForegroundServiceManager {
  static Future<void> initService() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'call_recorder_channel',
          channelName: 'Recorder Service',
          channelDescription: 'recording service with floating button',
          channelImportance: NotificationChannelImportance.DEFAULT,
          priority: NotificationPriority.DEFAULT,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: true,
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      print('Foreground service initialized successfully');
    } catch (e) {
      print('Failed to initialize foreground service: $e');
    }
  }

  static Future<bool> startService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        return true;
      }

      // Clear stale command file
      try {
        final dir = await getApplicationDocumentsDirectory();
        final cmdFile = File('${dir.path}/.recorder_command');
        if (cmdFile.existsSync()) cmdFile.writeAsStringSync('idle|');
      } catch (_) {}

      try {
        final result = await FlutterForegroundTask.startService(
          notificationTitle: 'Recorder',
          notificationText: 'Monitoring. Tap floating button to record.',
          callback: startCallback,
        );
        if (result is ServiceRequestFailure) {
          print('Foreground service error: ${result.error}');
          return false;
        }
      } catch (e) {
        print('Foreground service exception: $e');
        return false;
      }

      await Future.delayed(const Duration(seconds: 1));
      final running = await FlutterForegroundTask.isRunningService;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('service_running', running);
      return running;
    } catch (e) {
      print('startService error: $e');
      return false;
    }
  }

  static Future<bool> stopService() async {
    try {
      // Signal stop recording via command file
      try {
        final dir = await getApplicationDocumentsDirectory();
        final cmdFile = File('${dir.path}/.recorder_command');
        cmdFile.writeAsStringSync('stop|');
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));

      // Hide native overlay
      try {
        await NativeOverlayService.hideOverlay();
      } catch (_) {}

      // Also try Flutter overlay
      try {
        final isActive = await FlutterOverlayWindow.isActive();
        if (isActive) await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}

      try {
        await FlutterForegroundTask.stopService();
      } catch (e) {
        print('Foreground service stop exception: $e');
      }

      await SharedPreferences.getInstance().then(
        (p) => p.setBool('service_running', false),
      );

      // Clear command file
      try {
        final dir = await getApplicationDocumentsDirectory();
        final cmdFile = File('${dir.path}/.recorder_command');
        if (cmdFile.existsSync()) cmdFile.writeAsStringSync('idle|');
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));
      return !(await FlutterForegroundTask.isRunningService);
    } catch (e) {
      print('stopService error: $e');
      return false;
    }
  }

  /// Show the native draggable floating button overlay.
  static Future<void> showOverlay() async {
    try {
      // Prefer native overlay (draggable, edge-snapping)
      final hasPermission = await NativeOverlayService.hasOverlayPermission();
      if (hasPermission) {
        await NativeOverlayService.showOverlay();
        return;
      }

      // Fallback to Flutter overlay
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) return;

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Recorder',
        overlayContent: 'Tap to record',
        flag: OverlayFlag.focusPointer,
        positionGravity: PositionGravity.right,
        height: 140,
        width: 140,
      );
    } catch (e) {
      print('Show overlay exception: $e');
    }
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  static Future<bool> isOverlayActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (_) {
      return false;
    }
  }
}
