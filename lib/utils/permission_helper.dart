import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class to request permissions with explanation dialogs
class PermissionHelper {
  /// Show explanation dialog then request microphone permission
  static Future<bool> requestMicrophoneWithExplanation(
    BuildContext context,
  ) async {
    // Check if already granted
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    // Show explanation dialog
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mic, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(child: Text('Microphone Permission')),
          ],
        ),
        content: const Text(
          'This app needs microphone access to record calls. '
          'Your recordings will be securely stored and analyzed.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    // Request the permission
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Show explanation dialog then request phone permission
  static Future<bool> requestPhoneWithExplanation(BuildContext context) async {
    final status = await Permission.phone.status;
    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.phone, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(child: Text('Phone Permission')),
          ],
        ),
        content: const Text(
          'This app needs phone state access to detect incoming and outgoing calls '
          'for automatic recording.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    final result = await Permission.phone.request();
    return result.isGranted;
  }

  /// Show explanation dialog then request storage permission
  static Future<bool> requestStorageWithExplanation(
    BuildContext context,
  ) async {
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.folder, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(child: Text('Storage Permission')),
          ],
        ),
        content: const Text(
          'This app needs storage access to save your call recordings locally.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    final result = await Permission.storage.request();
    return result.isGranted;
  }

  /// Show explanation dialog then request notification permission
  static Future<bool> requestNotificationWithExplanation(
    BuildContext context,
  ) async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(child: Text('Notification Permission')),
          ],
        ),
        content: const Text(
          'This app needs notification access to show recording status and alerts.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Request all required permissions with explanations
  static Future<bool> requestAllPermissions(BuildContext context) async {
    // Request microphone first (most critical)
    final micGranted = await requestMicrophoneWithExplanation(context);
    if (!micGranted) {
      _showPermissionDeniedDialog(context, 'Microphone');
      return false;
    }

    // Request phone state permission (for call detection)
    final phoneGranted = await requestPhoneStateWithExplanation(context);
    // Don't block if phone state is denied - recording can still work

    // Request storage permission
    final storageGranted = await requestStorageWithExplanation(context);
    if (!storageGranted) {
      _showPermissionDeniedDialog(context, 'Storage');
      return false;
    }

    // Request notification permission (optional, don't block)
    await requestNotificationWithExplanation(context);

    return true;
  }

  /// Show explanation dialog then request phone state permission
  static Future<bool> requestPhoneStateWithExplanation(
    BuildContext context,
  ) async {
    final status = await Permission.phone.status;
    if (status.isGranted) return true;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.phone, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(child: Text('Phone State Permission')),
          ],
        ),
        content: const Text(
          'This app needs phone state access to detect incoming and outgoing calls for automatic recording.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    final result = await Permission.phone.request();
    return result.isGranted;
  }

  /// Show dialog when permission is denied
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String permissionName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            Expanded(child: Text('Permission Required')),
          ],
        ),
        content: Text(
          '$permissionName permission is required for the app to work properly. '
          'Please grant the permission in app settings.',
          style: const TextStyle(fontSize: 15, height: 1.5),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
