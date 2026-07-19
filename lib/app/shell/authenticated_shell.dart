import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reelpin/app/providers.dart';
import 'package:reelpin/app/shell/app_shell.dart';
import 'package:reelpin/app/user_state_coordinator.dart';
import 'package:reelpin/core/logging/app_logger.dart';
import 'package:reelpin/core/platform/notification_service.dart';
import 'package:reelpin/features/account/presentation/entitlements_viewmodel.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/features/sharing/data/sharing_api.dart';
import 'package:reelpin/features/sharing/services/share_handoff_service.dart';
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
  late final SharingApi _sharingApi;
  late final NotificationService _notificationService;
  late final EntitlementsViewModel _entitlementsViewModel;
  late final UserStateCoordinator _userStateCoordinator;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<ReelReadyNotification>? _reelReadySubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  String? _lastRegisteredPushUserId;
  String? _lastRegisteredPushToken;
  DateTime? _lastRegisteredPushAt;
  String? _activeUserId;
  Timer? _pushRegistrationRetryTimer;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _sharingApi = ref.read(sharingApiProvider);
    _notificationService = ref.read(notificationServiceProvider);
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
    return const AppShell();
  }

  Future<void> _initializeBackgroundMessaging() async {
    try {
      await _notificationService.initialize(requestPermissions: false);
    } catch (e) {
      AppLogger.error('Notification initialization skipped: $e');
      return;
    }

    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

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

    await _syncPushTokenRegistration();

    _reelReadySubscription = _notificationService.onReelReady.listen((event) {
      unawaited(_refreshSavedReels());
    });

    final initialReelReady = _notificationService
        .consumePendingInitialReelReady();
    if (initialReelReady != null) {
      await _refreshSavedReels();
    }
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

      await ShareHandoffService.instance.syncPushToken(
        token: normalizedToken,
        platform: _notificationService.currentPlatform,
      );
      await _sharingApi.registerPushToken(
        userId: userId,
        token: normalizedToken,
        platform: _notificationService.currentPlatform,
      );
      _lastRegisteredPushUserId = userId;
      _lastRegisteredPushToken = normalizedToken;
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

  void _clearUserScopedState() {
    _userStateCoordinator.reset();
    _lastRegisteredPushUserId = null;
    _lastRegisteredPushToken = null;
    _lastRegisteredPushAt = null;
  }

  @override
  void dispose() {
    _clearUserScopedState();
    _tokenRefreshSubscription?.cancel();
    _reelReadySubscription?.cancel();
    _authStateSubscription?.cancel();
    _pushRegistrationRetryTimer?.cancel();
    super.dispose();
  }
}
