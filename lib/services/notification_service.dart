import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'api_service.dart';
import '../utils/navigator_key.dart';
import '../screens/crm/crm_screen.dart';
import '../screens/crm_v2/crm_deal_detail_screen.dart';

/// Top-level handler for background messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message: ${message.messageId}');
  // When the app is in the background, Android auto-displays the notification
  // from the FCM 'notification' payload — do NOT call _showLocalNotification
  // here or the user will see two notifications for every push.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _tokenKey = 'fcm_token';
  static const String _tokenSentKey = 'fcm_token_sent';

  /// Initialize Firebase Messaging and local notifications
  Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'mystery_mentor_channel',
        'MysteryMentor Notifications',
        description: 'Notifications from MysteryMentor app',
        importance: Importance.high,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    // iOS: show foreground notifications
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('[FCM] Token: $token');
      await _saveAndSendToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      _saveAndSendToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Send FCM token to backend
  Future<void> sendTokenToBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return;

    try {
      final api = ApiService();
      await api.registerFcmToken(token);
      await prefs.setBool(_tokenSentKey, true);
      debugPrint('[FCM] Token sent to backend');
    } catch (e) {
      debugPrint('[FCM] Failed to send token to backend: $e');
    }
  }

  /// Save token locally and send to backend
  Future<void> _saveAndSendToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString(_tokenKey);

    // Only send if token changed
    if (oldToken != token) {
      await prefs.setString(_tokenKey, token);
      await prefs.setBool(_tokenSentKey, false);
    }

    // Try to send to backend
    await sendTokenToBackend();
  }

  /// Handle foreground messages — show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    // iOS: setForegroundNotificationPresentationOptions + AppDelegate willPresent
    //      already handle display — calling show() here would duplicate the banner
    if (Platform.isAndroid) {
      _showLocalNotification(message);
    }
  }

  /// Show a local notification from a RemoteMessage
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'mystery_mentor_channel',
      'MysteryMentor Notifications',
      channelDescription: 'Notifications from MysteryMentor app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await plugin.show(
      message.hashCode,
      notification.title ?? 'MysteryMentor',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap (foreground local notification)
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromData(data);
      } catch (_) {}
    }
  }

  /// Handle when user taps FCM notification (background/terminated)
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[FCM] Notification opened: ${message.data}');
    _navigateFromData(message.data);
  }

  /// Navigate based on notification data payload
  static void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final dealId = data['dealId']?.toString();
    final dealName = data['dealName']?.toString() ?? data['contactName']?.toString() ?? 'Lead';
    if (type == 'LEAD_ASSIGNED' && dealId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CrmSubWrapper(
              title: dealName,
              child: CrmDealDetailScreen(dealId: dealId, dealName: dealName),
            ),
          ),
        );
      });
    }
  }

  /// Unregister token (on logout)
  Future<void> unregisterToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      try {
        final api = ApiService();
        await api.unregisterFcmToken(token);
      } catch (_) {}
    }
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenSentKey);
  }

  /// Subscribe to a topic (e.g., company-wide notifications)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from topic: $topic');
  }
}
