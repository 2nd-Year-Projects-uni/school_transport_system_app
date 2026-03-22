import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level handler for background / terminated messages.
/// Must be a top-level function (not inside a class).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App is in background or terminated. FCM shows the notification
  // automatically on Android. Nothing extra needed unless you want
  // custom logic (e.g. update a badge count).
  debugPrint('[FCM Background] message received: ${message.messageId}');
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// High-priority Android notification channel for foreground messages.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'school_van_channel',       // id
    'School Van Alerts',        // name
    description: 'Notifications from the Ride Safe school van app.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _ongoingChannel = AndroidNotificationChannel(
    'school_van_ongoing',
    'Active Journey Tracking',
    description: 'Persistent notification shown while a journey is active.',
    importance: Importance.low,
  );

  // ────────────────────────────────────────────────────────────────────
  // Initialise – call this once from main()
  // ────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // 1. Register the background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request permission (iOS + Android 13+)
    await _requestPermission();

    // 3. Set-up local notifications (for foreground display)
    await _initLocalNotifications();

    // 4. Listen to foreground messages
    _listenForeground();

    // 5. Handle notification taps when app is in background (not terminated)
    _listenOnMessageOpenedApp();

    // 6. Handle notification tap when app was terminated
    await _checkInitialMessage();

    // 7. Subscribe to the global topic so any device can be reached for testing
    await _messaging.subscribeToTopic('all_devices');
    debugPrint('[FCM] Subscribed to topic: all_devices');

    // 8. Print token to console (handy during development)
    await getToken();
  }

  // ────────────────────────────────────────────────────────────────────
  // Permission
  // ────────────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  // ────────────────────────────────────────────────────────────────────
  // Local Notifications setup
  // ────────────────────────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle tap on a local notification here if needed
        debugPrint('[LocalNotif] tapped. payload: ${response.payload}');
      },
    );

    // Create the Android channel so that high-importance messages appear
    // as heads-up notifications even on Android 8+.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_ongoingChannel);
  }

  // ────────────────────────────────────────────────────────────────────
  // Foreground message listener
  // ────────────────────────────────────────────────────────────────────

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] ${message.notification?.title}');
      _showLocalNotification(message);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await showNoticeNotification(
      id: notification.hashCode & 0x7FFFFFFF,
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: message.data['route'],
    );
  }

  Future<void> showNoticeNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Ongoing Journey Notification
  // ────────────────────────────────────────────────────────────────────

  Future<void> showOngoingJourneyNotification() async {
    final androidDetails = AndroidNotificationDetails(
      _ongoingChannel.id,
      _ongoingChannel.name,
      channelDescription: _ongoingChannel.description,
      importance: Importance.low, // Silent but persistent
      priority: Priority.low,
      ongoing: true, // Cannot be swiped away
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.active,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      99999, // Reserved fixed ID for the ongoing journey
      'Journey in Progress',
      'Live tracking is active. Tap to return and manage your trip.',
      details,
    );
  }

  Future<void> endOngoingJourneyNotification() async {
    await _localNotifications.cancel(99999);
  }

  // ────────────────────────────────────────────────────────────────────
  // Tap handlers
  // ────────────────────────────────────────────────────────────────────

  void _listenOnMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] App opened from notification: ${message.messageId}');
      // TODO: navigate based on message.data['route'] when routing is wired up
    });
  }

  Future<void> _checkInitialMessage() async {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint(
          '[FCM] App launched from terminated state via notification: ${initial.messageId}');
      // TODO: navigate based on initial.data['route'] when routing is wired up
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Topic subscription helpers
  // ────────────────────────────────────────────────────────────────────

  /// Subscribe this device to a role-based topic after login.
  /// [userType] should match the Firestore field: 'parent', 'driver', 'vehicle_owner'
  Future<void> subscribeToUserTopic(String userType) async {
    // Map userType to a clean topic name
    final topic = userType.replaceAll('_', ''); // e.g. 'vehicle_owner' → 'vehicleowner'
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from role-based topic on logout.
  Future<void> unsubscribeFromUserTopic(String userType) async {
    final topic = userType.replaceAll('_', '');
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from topic: $topic');
  }

  // ────────────────────────────────────────────────────────────────────
  // FCM Token helpers
  // ────────────────────────────────────────────────────────────────────

  /// Returns the FCM token for this device, or null if unavailable.
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[FCM] Token: $token');
      return token;
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
      return null;
    }
  }

  /// Saves the FCM token to the currently signed-in user's Firestore document.
  /// Call this after login so targeted push notifications can be sent later.
  Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'fcmTokens': FieldValue.arrayUnion([token])
    });

    debugPrint('[FCM] Token saved to Firestore for user ${user.uid}');

    // Also listen for token refreshes and keep Firestore up to date
    _messaging.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': FieldValue.arrayUnion([newToken])
      });
      debugPrint('[FCM] Token refreshed and saved.');
    });
  }

  /// Removes the FCM token from Firestore on logout.
  Future<void> clearTokenFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': FieldValue.arrayRemove([token])
      });
    }

    // Also delete device token from FCM so no more messages are sent here
    if (Platform.isAndroid) {
      await _messaging.deleteToken();
    }
    debugPrint('[FCM] Token cleared from Firestore.');
  }
}
