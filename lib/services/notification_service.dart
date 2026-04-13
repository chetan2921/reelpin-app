import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/supabase_config.dart';
import '../models/recall_region.dart';

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

  static const proactiveRecallChannelId = 'reelpin_proactive_recall';
  static const proactiveRecallChannelName = 'Proactive Recall';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<ReelReadyNotification> _reelReadyController =
      StreamController<ReelReadyNotification>.broadcast();

  bool _initialized = false;
  bool _firebaseConfigured = false;
  ReelReadyNotification? _pendingInitialReelReady;

  bool get isFirebaseConfigured => _firebaseConfigured;
  Stream<ReelReadyNotification> get onReelReady => _reelReadyController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_supportsNativeFirebaseMessaging) return;

    _firebaseConfigured = Firebase.apps.isNotEmpty;
    if (!_firebaseConfigured) return;

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
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

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
              proactiveRecallChannelId,
              proactiveRecallChannelName,
              description:
                  'Context-aware reminders about places and reel insights you saved.',
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
          proactiveRecallChannelId,
          proactiveRecallChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showProactiveRecallNotification(RecallRegion region) async {
    final body = _buildRecallBody(region);
    await showMessageNotification(
      title: 'You are near ${region.locationName}',
      body: body,
    );
  }

  String _buildRecallBody(RecallRegion region) {
    final category = region.primaryCategory;
    if (category.toLowerCase().contains('fitness') ||
        category.toLowerCase().contains('gym')) {
      return 'You saved ${region.reelCount} workout reel${region.reelCount == 1 ? '' : 's'} for this spot. Tap to jump back in.';
    }

    if (category.toLowerCase().contains('food') ||
        category.toLowerCase().contains('travel')) {
      return 'You are close to ${region.locationName}. ReelPin found ${region.reelCount} saved idea${region.reelCount == 1 ? '' : 's'} here.';
    }

    return 'You saved ${region.reelCount} reel${region.reelCount == 1 ? '' : 's'} linked to ${region.locationName}. Open ReelPin to revisit them.';
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
