import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/data_models/notifications/app_notification.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (!_supportsNativeFirebaseMessaging) return;
    await Firebase.initializeApp();
  } catch (e) {
    AppLogger.error('Firebase background initialization skipped: $e');
  }
}

bool get _supportsNativeFirebaseMessaging =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get _usesSystemForegroundPresentation =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

enum NotificationPermissionState { enabled, disabled, unavailable }

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const updatesChannelId = 'reelpin_updates';
  static const updatesChannelName = 'Reel Updates';
  static const _permissionStateStorageKey = 'notification_permission_state_v1';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<AppNotification> _reelReadyController =
      StreamController<AppNotification>.broadcast();
  final StreamController<OpenedAppNotification> _notificationOpenedController =
      StreamController<OpenedAppNotification>.broadcast();
  final Map<String, DateTime> _recentForegroundNotifications = {};

  Future<void>? _initializationFuture;
  bool _firebaseConfigured = false;
  final List<OpenedAppNotification> _pendingNotificationOpens = [];
  NotificationPermissionState? _lastKnownPermissionState;
  String? _currentFcmToken;

  bool get isFirebaseConfigured => _firebaseConfigured;
  Stream<AppNotification> get onReelReady => _reelReadyController.stream;
  Stream<OpenedAppNotification> get onNotificationOpened =>
      _notificationOpenedController.stream;

  Future<void> initialize({bool requestPermissions = true}) async {
    _lastKnownPermissionState ??= await getLastKnownPermissionState();
    if (!_supportsNativeFirebaseMessaging) return;

    _firebaseConfigured = Firebase.apps.isNotEmpty;
    if (!_firebaseConfigured) return;

    _initializationFuture ??= _initializeOnce();
    try {
      await _initializationFuture;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
    if (requestPermissions) {
      await requestUserPermission();
    }
  }

  Future<void> _initializeOnce() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            updatesChannelId,
            updatesChannelName,
            description: 'Notifications for ReelPin updates.',
            importance: Importance.high,
          ),
        );

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: _usesSystemForegroundPresentation,
      badge: _usesSystemForegroundPresentation,
      sound: _usesSystemForegroundPresentation,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _dispatchNotificationOpen(
        OpenedAppNotification(
          notification: AppNotification.fromRemoteMessage(message),
          source: AppNotificationOpenSource.backgroundRemote,
        ),
      );
    });

    final localLaunch = await _localNotifications
        .getNotificationAppLaunchDetails();
    final localPayload = _nonEmpty(localLaunch?.notificationResponse?.payload);
    if (localLaunch?.didNotificationLaunchApp == true && localPayload != null) {
      _dispatchNotificationOpen(
        OpenedAppNotification(
          notification: AppNotification.fromLocalPayload(localPayload),
          source: AppNotificationOpenSource.terminatedLocal,
        ),
      );
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _dispatchNotificationOpen(
        OpenedAppNotification(
          notification: AppNotification.fromRemoteMessage(initialMessage),
          source: AppNotificationOpenSource.terminatedRemote,
        ),
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = AppNotification.fromRemoteMessage(message);
    if (notification.isReelReady) {
      _reelReadyController.add(notification);
    }

    if (!_shouldShowLocalForegroundNotification(message) ||
        !_shouldPresentForegroundNotification(notification)) {
      return;
    }
    unawaited(
      showMessageNotification(notification).catchError((error) {
        AppLogger.error('Foreground notification display failed: $error');
      }),
    );
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    _dispatchNotificationOpen(
      OpenedAppNotification(
        notification: AppNotification.fromLocalPayload(response.payload),
        source: AppNotificationOpenSource.foregroundLocal,
      ),
    );
  }

  void _dispatchNotificationOpen(OpenedAppNotification opened) {
    if (_notificationOpenedController.hasListener) {
      _notificationOpenedController.add(opened);
      return;
    }
    _pendingNotificationOpens.add(opened);
  }

  List<OpenedAppNotification> consumePendingNotificationOpens() {
    final pending = List<OpenedAppNotification>.of(_pendingNotificationOpens);
    _pendingNotificationOpens.clear();
    return pending;
  }

  Future<NotificationSettings?> requestUserPermission() async {
    if (!_supportsNativeFirebaseMessaging || !_firebaseConfigured) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _persistPermissionState(
      _mapAuthorizationStatus(settings.authorizationStatus),
    );
    return settings;
  }

  Future<NotificationPermissionState?> getLastKnownPermissionState() async {
    if (_lastKnownPermissionState != null) {
      return _lastKnownPermissionState;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_permissionStateStorageKey);
    _lastKnownPermissionState = switch (rawValue) {
      'enabled' => NotificationPermissionState.enabled,
      'disabled' => NotificationPermissionState.disabled,
      'unavailable' => NotificationPermissionState.unavailable,
      _ => null,
    };
    return _lastKnownPermissionState;
  }

  Future<NotificationPermissionState> getPermissionState() async {
    if (!_supportsNativeFirebaseMessaging) {
      const state = NotificationPermissionState.unavailable;
      await _persistPermissionState(state);
      return state;
    }

    _firebaseConfigured = Firebase.apps.isNotEmpty;
    if (!_firebaseConfigured) {
      const state = NotificationPermissionState.unavailable;
      await _persistPermissionState(state);
      return state;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      if (enabled != null) {
        final state = enabled
            ? NotificationPermissionState.enabled
            : NotificationPermissionState.disabled;
        await _persistPermissionState(state);
        return state;
      }
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final state = _mapAuthorizationStatus(settings.authorizationStatus);
    await _persistPermissionState(state);
    return state;
  }

  Future<String?> getFcmToken({
    Duration apnsTimeout = const Duration(seconds: 5),
  }) async {
    if (!SupabaseConfig.isConfigured || !_firebaseConfigured) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _waitForApnsToken(timeout: apnsTimeout);
        if (apnsToken == null || apnsToken.trim().isEmpty) {
          AppLogger.error(
            'FCM token unavailable: APNs token is not available yet.',
          );
          return null;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      _currentFcmToken = _nonEmpty(token);
      AppLogger.info(
        _currentFcmToken == null
            ? 'FCM token unavailable: Firebase returned no token.'
            : 'FCM token available for $currentPlatform.',
      );
      return _currentFcmToken;
    } catch (e) {
      AppLogger.error('FCM token unavailable: $e');
      return null;
    }
  }

  Future<String?> getCurrentFcmToken() async {
    return _currentFcmToken ?? getFcmToken();
  }

  void rememberFcmToken(String token) {
    _currentFcmToken = _nonEmpty(token);
  }

  Stream<String> get onTokenRefresh => _firebaseConfigured
      ? FirebaseMessaging.instance.onTokenRefresh.map((token) {
          rememberFcmToken(token);
          return token;
        })
      : const Stream<String>.empty();

  Future<void> showMessageNotification(AppNotification notification) async {
    await _localNotifications.show(
      _notificationIdFor(notification),
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          updatesChannelId,
          updatesChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: notification.toLocalPayload(),
    );
  }

  String get currentPlatform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    return 'unknown';
  }

  bool _shouldPresentForegroundNotification(AppNotification notification) {
    final key =
        notification.notificationId ??
        notification.reelId ??
        notification.campaignId ??
        '${notification.title}:${notification.body}';
    final now = DateTime.now();
    _recentForegroundNotifications.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 2),
    );
    final lastSeen = _recentForegroundNotifications[key];
    if (lastSeen != null &&
        now.difference(lastSeen) < const Duration(seconds: 30)) {
      return false;
    }
    _recentForegroundNotifications[key] = now;
    return true;
  }

  bool _shouldShowLocalForegroundNotification(RemoteMessage message) {
    return !(_usesSystemForegroundPresentation && message.notification != null);
  }

  NotificationPermissionState _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      return NotificationPermissionState.enabled;
    }
    return NotificationPermissionState.disabled;
  }

  Future<void> _persistPermissionState(
    NotificationPermissionState state,
  ) async {
    _lastKnownPermissionState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_permissionStateStorageKey, switch (state) {
      NotificationPermissionState.enabled => 'enabled',
      NotificationPermissionState.disabled => 'disabled',
      NotificationPermissionState.unavailable => 'unavailable',
    });
  }

  Future<String?> _waitForApnsToken({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null && token.trim().isNotEmpty) return token;

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 500)
            ? remaining
            : const Duration(milliseconds: 500),
      );
    }
    return null;
  }

  int _notificationIdFor(AppNotification notification) {
    final source =
        notification.notificationId ??
        notification.reelId ??
        notification.campaignId ??
        '${notification.title}:${notification.body}';
    var hash = 0;
    for (final codeUnit in source.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
