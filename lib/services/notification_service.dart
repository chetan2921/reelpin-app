import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/supabase_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (!_supportsNativeFirebaseMessaging) return;
    await Firebase.initializeApp();
  } catch (_) {}
}

bool get _supportsNativeFirebaseMessaging =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class ReelReadyNotification {
  const ReelReadyNotification({
    required this.title,
    required this.body,
    this.reelId,
    this.jobId,
  });

  final String title;
  final String body;
  final String? reelId;
  final String? jobId;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const updatesChannelId = 'reelpin_updates';
  static const updatesChannelName = 'Reel Updates';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<ReelReadyNotification> _reelReadyController =
      StreamController<ReelReadyNotification>.broadcast();

  bool _initialized = false;
  bool _firebaseConfigured = false;
  ReelReadyNotification? _pendingInitialReelReady;

  bool get isFirebaseConfigured => _firebaseConfigured;
  Stream<ReelReadyNotification> get onReelReady => _reelReadyController.stream;

  Future<void> initialize({bool requestPermissions = true}) async {
    if (!_supportsNativeFirebaseMessaging) return;

    _firebaseConfigured = Firebase.apps.isNotEmpty;
    if (!_firebaseConfigured) return;

    if (_initialized) {
      if (requestPermissions) {
        await requestUserPermission();
      }
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    if (requestPermissions) {
      await requestUserPermission();
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              updatesChannelId,
              updatesChannelName,
              description: 'Notifications for completed reel processing.',
              importance: Importance.high,
            ),
          );
    }

    FirebaseMessaging.onMessage.listen((message) {
      final reelReady = _parseReelReady(message);
      if (reelReady != null) {
        unawaited(
          showMessageNotification(title: reelReady.title, body: reelReady.body),
        );
        _reelReadyController.add(reelReady);
        return;
      }

      final notification = message.notification;
      if (notification == null) return;
      unawaited(
        showMessageNotification(
          title: notification.title ?? 'ReelPin',
          body: notification.body ?? '',
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final reelReady = _parseReelReady(message);
      if (reelReady != null) {
        _reelReadyController.add(reelReady);
      }
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _pendingInitialReelReady = _parseReelReady(initialMessage);
    }

    _initialized = true;
  }

  Future<NotificationSettings?> requestUserPermission() async {
    if (!_supportsNativeFirebaseMessaging || !_firebaseConfigured) {
      return null;
    }

    return FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<String?> getFcmToken() async {
    if (!SupabaseConfig.isConfigured) return null;
    if (!_firebaseConfigured) return null;
    try {
      return FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _firebaseConfigured
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream<String>.empty();

  ReelReadyNotification? consumePendingInitialReelReady() {
    final pending = _pendingInitialReelReady;
    _pendingInitialReelReady = null;
    return pending;
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          updatesChannelId,
          updatesChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  String get currentPlatform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    return 'unknown';
  }

  ReelReadyNotification? _parseReelReady(RemoteMessage message) {
    final type = message.data['type']?.trim().toLowerCase();
    if (type != 'reel_ready') {
      return null;
    }

    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();
    final reelId = message.data['reel_id']?.trim();
    final jobId = message.data['job_id']?.trim();

    return ReelReadyNotification(
      title: title == null || title.isEmpty ? 'Reel pinned in ReelPin' : title,
      body: body == null || body.isEmpty
          ? 'Your saved reel is ready in ReelPin.'
          : body,
      reelId: reelId == null || reelId.isEmpty ? null : reelId,
      jobId: jobId == null || jobId.isEmpty ? null : jobId,
    );
  }
}
