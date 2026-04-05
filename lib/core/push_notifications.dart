import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'admin_session.dart';
import 'app_api.dart';

class PushNotifications {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await Firebase.initializeApp();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'wildpulse_captures',
      'WildPulse Captures',
      description: 'Capture notifications',
      importance: Importance.high,
    );
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _messaging.onTokenRefresh.listen(_registerToken);

    _initialized = true;
  }

  static Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    await initialize();
    final token = await _messaging.getToken();
    if (token == null) return;
    await _registerToken(token);
  }

  static Future<void> _registerToken(String token) async {
    if ((AdminSession.adminKey ?? '').isEmpty) return;

    try {
      await AppApi.postAdmin(
        '/devices/${AppApi.deviceId}/fcm-token',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'platform': Platform.operatingSystem,
        }),
      );
    } catch (_) {
      // Ignore token registration errors; retry on next app launch.
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'wildpulse_captures',
      'WildPulse Captures',
      channelDescription: 'Capture notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'New capture',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }
}
