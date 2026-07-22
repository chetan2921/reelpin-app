import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reelpin/app/providers.dart';
import 'package:reelpin/app/shell/app_shell.dart';
import 'package:reelpin/app/user_state_coordinator.dart';
import 'package:reelpin/core/logging/app_logger.dart';
import 'package:reelpin/core/platform/app_notification.dart';
import 'package:reelpin/core/platform/notification_service.dart';
import 'package:reelpin/core/platform/notification_tap_handler.dart';
import 'package:reelpin/features/account/presentation/entitlements_viewmodel.dart';
import 'package:reelpin/features/account/presentation/profile_screen.dart';
import 'package:reelpin/features/announcements/presentation/feature_announcement_screen.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/features/reels/presentation/detail/reel_detail_loader_screen.dart';
import 'package:reelpin/features/sharing/services/push_registration_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthenticatedShell extends ConsumerStatefulWidget {
  const AuthenticatedShell({super.key});

  @override
  ConsumerState<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell> {
  static const _pushRegistrationInterval = Duration(hours: 12);
  static const _pushRegistrationRetryInterval = Duration(seconds: 8);
  static const _pushRegistrationMaxAttempts = 4;

  late final AuthService _authService;
  late final NotificationService _notificationService;
  late final PushRegistrationService _pushRegistrationService;
  late final EntitlementsViewModel _entitlementsViewModel;
  late final UserStateCoordinator _userStateCoordinator;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<AppNotification>? _reelReadySubscription;
  StreamSubscription<OpenedAppNotification>? _notificationOpenedSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  String? _lastRegisteredPushUserId;
  String? _lastRegisteredPushToken;
  DateTime? _lastRegisteredPushAt;
  String? _activeUserId;
  Timer? _pushRegistrationRetryTimer;
  OpenedAppNotification? _deferredNotificationOpen;
  final NotificationTapHandler _notificationTapHandler =
      NotificationTapHandler();
  final AppShellController _appShellController = AppShellController();

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _notificationService = ref.read(notificationServiceProvider);
    _pushRegistrationService = ref.read(pushRegistrationServiceProvider);
    _entitlementsViewModel = ref.read(entitlementsViewModelProvider);
    _userStateCoordinator = ref.read(userStateCoordinatorProvider);
    _activeUserId = _authService.currentUser?.id;
    _authStateSubscription = _authService.authStateChanges.listen((state) {
      final nextUserId = state.session?.user.id;
      if (nextUserId == _activeUserId) return;
      _activeUserId = nextUserId;
      _clearUserScopedState();
      if (nextUserId != null && nextUserId.trim().isNotEmpty) {
        unawaited(_entitlementsViewModel.refresh(reloadContent: true));
        unawaited(_syncPushTokenRegistration());
        final deferred = _deferredNotificationOpen;
        if (deferred != null) {
          _deferredNotificationOpen = null;
          _queueNotificationOpen(deferred);
        }
      }
    });
    _initializeBackgroundMessaging();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_entitlementsViewModel.refresh(reloadContent: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(controller: _appShellController);
  }

  Future<void> _initializeBackgroundMessaging() async {
    try {
      await _notificationService.initialize(requestPermissions: false);
    } catch (e) {
      AppLogger.error('Notification initialization skipped: $e');
      return;
    }

    if (_notificationService.isFirebaseConfigured) {
      _tokenRefreshSubscription = _notificationService.onTokenRefresh.listen((
        token,
      ) {
        unawaited(
          _syncPushTokenRegistration(candidateToken: token).catchError((error) {
            AppLogger.error('Push token refresh sync failed: $error');
          }),
        );
      });
    }

    _reelReadySubscription = _notificationService.onReelReady.listen((event) {
      unawaited(_refreshSavedReels());
    });
    _notificationOpenedSubscription = _notificationService.onNotificationOpened
        .listen(_queueNotificationOpen);

    final pendingOpen = _notificationService.consumePendingNotificationOpen();
    if (pendingOpen != null) {
      _queueNotificationOpen(pendingOpen);
    }

    await _syncPushTokenRegistration();
  }

  Future<void> _syncPushTokenRegistration({
    String? candidateToken,
    int retryAttempt = 1,
  }) async {
    if (!mounted) return;

    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    try {
      final token = candidateToken?.trim().isNotEmpty == true
          ? candidateToken!.trim()
          : await _notificationService.getFcmToken(
              apnsTimeout: const Duration(seconds: 12),
            );
      if (token == null || token.trim().isEmpty) {
        _schedulePushTokenRegistrationRetry(attempt: retryAttempt);
        return;
      }

      final normalizedToken = token.trim();
      final recentlyRegistered =
          _lastRegisteredPushAt != null &&
          DateTime.now().difference(_lastRegisteredPushAt!) <
              _pushRegistrationInterval;
      final isDuplicateRegistration =
          _lastRegisteredPushUserId == userId &&
          _lastRegisteredPushToken == normalizedToken &&
          recentlyRegistered;
      if (isDuplicateRegistration) {
        return;
      }

      final registeredToken = await _pushRegistrationService.register(
        userId: userId,
        candidateToken: normalizedToken,
        apnsTimeout: const Duration(seconds: 12),
      );
      if (registeredToken == null) {
        _schedulePushTokenRegistrationRetry(attempt: retryAttempt);
        return;
      }
      _lastRegisteredPushUserId = userId;
      _lastRegisteredPushToken = registeredToken;
      _lastRegisteredPushAt = DateTime.now();
      _pushRegistrationRetryTimer?.cancel();
      _pushRegistrationRetryTimer = null;
    } catch (e) {
      AppLogger.error('Push token registration skipped: $e');
      _schedulePushTokenRegistrationRetry(attempt: retryAttempt);
    }
  }

  void _schedulePushTokenRegistrationRetry({int attempt = 1}) {
    if (attempt > _pushRegistrationMaxAttempts) return;
    if (_pushRegistrationRetryTimer?.isActive == true) return;

    _pushRegistrationRetryTimer = Timer(_pushRegistrationRetryInterval, () {
      _pushRegistrationRetryTimer = null;
      if (!mounted) return;
      unawaited(_syncPushTokenRegistration(retryAttempt: attempt + 1));
    });
  }

  Future<void> _refreshSavedReels() async {
    try {
      await _entitlementsViewModel.refresh(reloadContent: true);
    } catch (e) {
      AppLogger.error('Saved reel refresh skipped: $e');
    }
  }

  void _queueNotificationOpen(OpenedAppNotification opened) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_handleNotificationOpen(opened));
    });
  }

  Future<void> _handleNotificationOpen(OpenedAppNotification opened) async {
    if (_authService.currentUser == null) {
      _deferredNotificationOpen = opened;
      return;
    }

    await _notificationTapHandler.handle(
      opened,
      trackOpen: _recordNotificationOpen,
      openReel: (reelId) async {
        unawaited(_refreshSavedReels());
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReelDetailLoaderScreen(reelId: reelId),
          ),
        );
      },
      openAnnouncement: (notification) async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FeatureAnnouncementScreen(
              title: notification.title,
              body: notification.body,
            ),
          ),
        );
      },
      openHome: () async {
        _openShellTab(_appShellController.showHome);
      },
      openMap: () async {
        _openShellTab(_appShellController.showMap);
      },
      openDiscover: () async {
        _openShellTab(_appShellController.showDiscover);
      },
      openProfile: () async {
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route.isFirst);
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
        );
      },
    );
  }

  void _openShellTab(VoidCallback selectTab) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    selectTab();
  }

  Future<void> _recordNotificationOpen(String notificationId) async {
    try {
      await _pushRegistrationService.recordNotificationOpened(notificationId);
    } catch (e) {
      AppLogger.error('Notification open tracking skipped: $e');
    }
  }

  void _clearUserScopedState() {
    _userStateCoordinator.reset();
    _lastRegisteredPushUserId = null;
    _lastRegisteredPushToken = null;
    _lastRegisteredPushAt = null;
    _notificationTapHandler.clear();
  }

  @override
  void dispose() {
    _clearUserScopedState();
    _tokenRefreshSubscription?.cancel();
    _reelReadySubscription?.cancel();
    _notificationOpenedSubscription?.cancel();
    _authStateSubscription?.cancel();
    _pushRegistrationRetryTimer?.cancel();
    super.dispose();
  }
}
