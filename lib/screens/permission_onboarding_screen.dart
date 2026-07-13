import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../utils/permission_helper.dart';
import 'home_screen.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  bool _isRequesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    try {
      // Request microphone — result is best-effort; iOS 17+ deprecated the
      // underlying AVAudioSession API so permission_handler may return false
      // even after the user grants. We proceed regardless and let feature
      // screens re-check when they actually need the mic.
      await PermissionHelper.requestMicrophoneWithExplanation(context);

      // Phone state and storage are Android-only
      if (!Platform.isIOS) {
        if (!mounted) return;
        await PermissionHelper.requestPhoneStateWithExplanation(context);
        if (!mounted) return;
        await PermissionHelper.requestStorageWithExplanation(context);
      }

      // Notification (optional) — timeout guards against iOS hangs
      try {
        if (mounted) {
          await PermissionHelper.requestNotificationWithExplanation(context)
              .timeout(const Duration(seconds: 15));
        }
      } catch (_) {}

      // Battery optimization — prompt Oppo/Vivo/Realme users to disable it
      // so recordings are never interrupted by the OEM's background killer.
      if (!Platform.isIOS && mounted) {
        await _requestBatteryOptimizationIfNeeded();
      }

      // Mark onboarding complete and navigate regardless of permission results
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_onboarding_complete', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _isRequesting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _requestBatteryOptimizationIfNeeded() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return;

      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = info.manufacturer.toLowerCase();
      final isAggressiveOem = manufacturer.contains('oppo') ||
          manufacturer.contains('vivo') ||
          manufacturer.contains('realme') ||
          manufacturer.contains('oneplus') ||
          manufacturer.contains('xiaomi') ||
          manufacturer.contains('redmi') ||
          manufacturer.contains('huawei') ||
          manufacturer.contains('honor');

      if (!mounted) return;

      // Show an explanation dialog for aggressive OEMs, then request for all
      if (isAggressiveOem) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.battery_alert, color: Color(0xFFF59E0B)),
                SizedBox(width: 12),
                Expanded(child: Text('Important for Recording')),
              ],
            ),
            content: const Text(
              'Your device\'s battery optimization may stop recordings after 2-3 minutes.\n\n'
              'On the next screen, tap "Allow" to let this app run in the background without interruption.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
  }

  Future<void> _skip() async {
    // Mark as complete even if skipped (user can grant later)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_onboarding_complete', true);

    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                const Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  'To provide the best experience, we need access to:',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Permission items
                _buildPermissionItem(
                  Icons.mic_rounded,
                  'Microphone',
                  'Record calls for analysis',
                ),
                if (!Platform.isIOS) ...[
                  const SizedBox(height: 16),
                  _buildPermissionItem(
                    Icons.phone_rounded,
                    'Phone State',
                    'Detect calls automatically',
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionItem(
                    Icons.folder_rounded,
                    'Storage',
                    'Save recordings locally',
                  ),
                ],
                const SizedBox(height: 16),
                _buildPermissionItem(
                  Icons.notifications_rounded,
                  'Notifications',
                  'Show recording status',
                ),
                if (!Platform.isIOS) ...[
                  const SizedBox(height: 16),
                  _buildPermissionItem(
                    Icons.battery_charging_full_rounded,
                    'Battery Optimization',
                    'Prevent recordings from being cut off',
                  ),
                ],

                const SizedBox(height: 40),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          )
                        : const Text(
                            'Grant Permissions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip button
                TextButton(
                  onPressed: _isRequesting ? null : _skip,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
