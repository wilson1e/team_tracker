import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../notification_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _saveCurrentToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.showInstantTeamUpdateNotification(
        id: message.messageId?.hashCode.abs() ??
            DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: notification.title ?? 'Team Tracker',
        body: notification.body ?? '你有新通知',
      );
    });
  }

  Future<void> syncTokenForCurrentUser() async {
    if (kIsWeb) return;
    try {
      await _saveCurrentToken();
    } catch (e, st) {
      debugPrint('FCM token sync skipped: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(token)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
