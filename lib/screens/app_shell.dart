import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/share_handoff_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'paywall_screen.dart';
import 'search_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const _permissionsPromptedKey =
      'app_shell_initial_permissions_prompted_v5';
  static const _shareConfirmationDuration = Duration(milliseconds: 1400);
  static const _resumeRefreshInterval = Duration(minutes: 5);

  int _currentIndex = 0;
  StreamSubscription? _mediaIntentSub;
  bool _isQueueingSharedReel = false;
  String? _lastHandledSharedPayload;
  bool _isCheckingInitialPermissions = false;
  int _searchFocusRequestId = 0;
  DateTime? _lastResumeRefreshAt;

  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'HOME',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'MAP',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'DISCOVER',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSharingIntent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybePromptInitialPermissions());
    });
  }

  void _initSharingIntent() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return;
    }

    _mediaIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        _processSharedData(value);
      },
      onError: (err) {
        debugPrint("Intent stream error: $err");
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _processSharedData(value);
    });
  }

  void _processSharedData(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final payload = files.first.path;
    unawaited(_handleSharedPayload(payload));
    unawaited(ReceiveSharingIntent.instance.reset());
  }

  Future<void> _handleSharedPayload(String payload) async {
    final normalizedPayload = payload.trim();
    if (normalizedPayload.isEmpty) return;

    final analytics = ref.read(shareFlowAnalyticsServiceProvider);
    unawaited(analytics.recordShareDetected(normalizedPayload));
    if (_lastHandledSharedPayload == normalizedPayload) {
      unawaited(analytics.recordDuplicateShareSkipped(normalizedPayload));
      return;
    }
    _lastHandledSharedPayload = normalizedPayload;

    try {
      final resolved = await ref
          .read(apiServiceProvider)
          .resolveSharePayload(
            rawPayloadText: normalizedPayload,
            platform: Theme.of(context).platform.name,
          );
      if (!mounted || !resolved.supported) return;

      final resolvedUrl = resolved.normalizedUrl ?? resolved.extractedUrl;
      if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
        return;
      }
      await _enqueueSharedReel(resolvedUrl);
    } catch (error) {
      unawaited(analytics.recordEnqueueFailed(normalizedPayload, error));
    }
  }

  Future<void> _enqueueSharedReel(String url) async {
    if (_isQueueingSharedReel) return;

    final homeVm = ref.read(homeViewModelProvider);
    final analytics = ref.read(shareFlowAnalyticsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isQueueingSharedReel = true;
    });

    try {
      await _syncPushTokenRegistrationIfPossible();
      unawaited(analytics.recordEnqueueStarted(url));
      await homeVm.enqueueReelProcessing(url);
      unawaited(ref.read(entitlementsViewModelProvider).refresh());

      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });
      unawaited(analytics.recordEnqueueSucceeded(url));

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                color: AppTheme.neonGreen,
                child: Icon(Icons.check, size: 14, color: AppTheme.fg(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SAVED TO REELPIN. PROCESSING IN BACKGROUND.',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.bg(context),
          behavior: SnackBarBehavior.floating,
          duration: _shareConfirmationDuration,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppTheme.fg(context),
              width: AppTheme.borderWidth,
            ),
          ),
        ),
      );

      if (!mounted) return;
      if (Theme.of(context).platform == TargetPlatform.android) {
        await Future<void>.delayed(_shareConfirmationDuration);
        if (!mounted) return;
        await SystemNavigator.pop();
      }
    } catch (error) {
      if (error is ApiException && error.isMonthlyReelLimitReached) {
        unawaited(analytics.recordEnqueueFailed(url, error));
        await ref.read(entitlementsViewModelProvider).refresh();
        if (!mounted) return;
        setState(() {
          _isQueueingSharedReel = false;
        });
        await openPaywall(context, entryPoint: PaywallEntryPoint.saveLimit);
        return;
      }

      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });
      unawaited(analytics.recordEnqueueFailed(url, error));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallbackMessage: 'Could not start background save.',
            ),
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppTheme.fg(context),
              width: AppTheme.borderWidth,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaIntentSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    final now = DateTime.now();
    if (_lastResumeRefreshAt != null &&
        now.difference(_lastResumeRefreshAt!) < _resumeRefreshInterval) {
      return;
    }
    _lastResumeRefreshAt = now;

    unawaited(
      ref.read(entitlementsViewModelProvider).refresh(reloadContent: true),
    );
  }

  Future<void> _maybePromptInitialPermissions() async {
    if (!mounted || _isCheckingInitialPermissions) return;

    _isCheckingInitialPermissions = true;
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_permissionsPromptedKey) ?? false;
    if (alreadyPrompted) {
      _isCheckingInitialPermissions = false;
      return;
    }

    final attempted = await _enableReelPinPermissions();
    if (attempted) {
      await prefs.setBool(_permissionsPromptedKey, true);
    }
    _isCheckingInitialPermissions = false;
  }

  Future<bool> _enableReelPinPermissions() async {
    final notificationService = ref.read(notificationServiceProvider);
    final apiService = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

    try {
      await notificationService.initialize(requestPermissions: false);
      final initialState = await notificationService.getPermissionState();
      if (initialState == NotificationPermissionState.disabled) {
        await notificationService.requestUserPermission();
      }
    } catch (e) {
      debugPrint('Notification permission setup skipped: $e');
      return false;
    }

    final currentState = await notificationService.getPermissionState();
    final userId = authService.currentUser?.id;
    if (currentState == NotificationPermissionState.enabled &&
        userId != null &&
        userId.trim().isNotEmpty) {
      try {
        final token = await notificationService.getFcmToken();
        if (token != null && token.trim().isNotEmpty) {
          await apiService.registerPushToken(
            userId: userId,
            token: token,
            platform: notificationService.currentPlatform,
          );
          await ShareHandoffService.instance.syncPushToken(
            token: token,
            platform: notificationService.currentPlatform,
          );
        }
      } catch (e) {
        debugPrint('Push token registration skipped after prompt: $e');
      }
    }

    return true;
  }

  Future<void> _syncPushTokenRegistrationIfPossible() async {
    final notificationService = ref.read(notificationServiceProvider);
    final apiService = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    try {
      await notificationService.initialize(requestPermissions: false);
      final token = await notificationService.getFcmToken();
      if (token == null || token.trim().isEmpty) return;

      await apiService.registerPushToken(
        userId: userId,
        token: token.trim(),
        platform: notificationService.currentPlatform,
      );
      await ShareHandoffService.instance.syncPushToken(
        token: token.trim(),
        platform: notificationService.currentPlatform,
      );
    } catch (e) {
      debugPrint('Push token registration skipped before share enqueue: $e');
    }
  }

  void _openSearchFromHome() {
    setState(() {
      _currentIndex = 2;
      _searchFocusRequestId += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.bg(context),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(onSearchTap: _openSearchFromHome),
            const MapScreen(),
            SearchScreen(focusRequestId: _searchFocusRequestId),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (i) {
              return _buildNavItem(i, _navItems[i]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.yellow : Colors.transparent,
          border: isSelected
              ? Border.all(color: AppTheme.fg(context), width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.black : AppTheme.fg(context),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.spaceMono(
                color: isSelected ? AppTheme.black : AppTheme.fg(context),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
