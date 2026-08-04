import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/providers.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/services/notifications/notification_service.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/services/how_to_guide_service.dart';
import 'package:reelpin/services/location/location_service.dart';
import 'package:reelpin/services/sharing/share_handoff_service.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/screens/home/home_screen.dart';
import 'package:reelpin/screens/map/map_screen.dart';
import 'package:reelpin/screens/paywall/paywall_screen.dart';
import 'package:reelpin/screens/discover/discover_screen.dart';
import 'package:reelpin/screens/collections/collection_detail_screen.dart';
import 'package:reelpin/screens/collections/collections_screen.dart';

part 'partials/app_shell_controller.dart';
part 'partials/nav_item.dart';

const _navIconSize = 27.0;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.controller});

  final AppShellController? controller;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const _permissionsPromptedKey =
      'app_shell_initial_permissions_prompted_v6';
  static const _shareConfirmationDuration = Duration(milliseconds: 1400);
  static const _resumeRefreshInterval = Duration(minutes: 5);
  static const _floatingNavHeight = 56.0;
  static const _floatingNavBottomInset = 14.0;
  static const _floatingNavHorizontalInset = 60.0;

  int _currentIndex = 0;
  StreamSubscription? _mediaIntentSub;
  AppLinks? _appLinks;
  StreamSubscription? _deepLinkSub;
  bool _isQueueingSharedReel = false;
  String? _lastHandledSharedPayload;
  bool _isCheckingInitialPermissions = false;
  int _searchFocusRequestId = 0;
  DateTime? _lastResumeRefreshAt;
  final ScrollController _homeScrollController = ScrollController();

  static const _navItems = [
    _NavItem(icon: HugeIcons.strokeRoundedHome04, label: 'HOME'),
    _NavItem(icon: HugeIcons.strokeRoundedLocation03, label: 'MAP'),
    _NavItem(icon: HugeIcons.strokeRoundedDiscoverSquare, label: 'DISCOVER'),
    _NavItem(icon: HugeIcons.strokeRoundedBookmark02, label: 'SAVED'),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_selectControlledTab);
    WidgetsBinding.instance.addObserver(this);
    _initSharingIntent();
    unawaited(_initCollectionDeepLinks());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runFirstRunFlow());
      unawaited(_drainPendingNativeShares());
    });
  }

  Future<void> _initCollectionDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final initial = await _appLinks!.getInitialLink();
      if (initial != null) _handleIncomingUri(initial);
    } catch (_) {}
    _deepLinkSub = _appLinks!.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (_) {},
    );
  }

  void _handleIncomingUri(Uri uri) {
    // https://reelpin.in/c/{token}  or  /c/invite/{token}
    final segments = uri.pathSegments;
    if (segments.isEmpty || segments.first != 'c') return;
    if (segments.length >= 3 && segments[1] == 'invite') {
      unawaited(_acceptCollectionInvite(segments[2]));
    } else if (segments.length >= 2) {
      unawaited(_openSharedCollection(segments[1]));
    }
  }

  Future<void> _openSharedCollection(String token) async {
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CollectionDetailScreen(collectionId: '', sharedToken: token),
      ),
    );
  }

  Future<void> _acceptCollectionInvite(String token) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final joined = await ref
          .read(collectionsViewModelProvider)
          .acceptInvite(token);
      if (joined != null && mounted) {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => CollectionDetailScreen(collectionId: joined.id),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This invite is no longer valid.')),
      );
    }
  }

  void _initSharingIntent() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Mobile shares are captured natively into a pending list and enqueued
      // via background share tokens, so we don't use the redirecting intent
      // stream on Android or iOS.
      return;
    }

    _mediaIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        _processSharedData(value);
      },
      onError: (err) {
        AppLogger.error("Intent stream error: $err");
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

  Future<void> _handleSharedPayload(
    String payload, {
    bool showConfirmation = true,
  }) async {
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
      // Send the whole payload; the backend extracts the URL candidates and
      // decides which is the intended, supported one.
      final resolved = await ref
          .read(sharingHttpProvider)
          .resolveSharePayload(
            rawPayloadText: normalizedPayload,
            platform: Theme.of(context).platform.name,
          );
      if (!mounted || !resolved.supported) return;

      final resolvedUrl = resolved.normalizedUrl ?? resolved.extractedUrl;
      if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
        return;
      }
      await _enqueueSharedReel(resolvedUrl, showConfirmation: showConfirmation);
    } catch (error) {
      unawaited(analytics.recordEnqueueFailed(normalizedPayload, error));
    }
  }

  Future<void> _enqueueSharedReel(
    String url, {
    required bool showConfirmation,
  }) async {
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
      unawaited(_refreshSavedContent());

      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });
      unawaited(analytics.recordEnqueueSucceeded(url));

      if (showConfirmation) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  color: AppColors.neonGreen,
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.fg(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SAVED TO REELPIN. PROCESSING IN BACKGROUND.',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.bg(context),
            behavior: SnackBarBehavior.floating,
            duration: _shareConfirmationDuration,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: AppColors.fg(context),
                width: AppTheme.borderWidth,
              ),
            ),
          ),
        );
      }

      if (!mounted) return;
      if (showConfirmation &&
          Theme.of(context).platform == TargetPlatform.android) {
        await Future<void>.delayed(_shareConfirmationDuration);
        if (!mounted) return;
        await SystemNavigator.pop();
      }
    } catch (error) {
      if (error is ApiException && error.isMonthlyReelLimitReached) {
        unawaited(analytics.recordEnqueueFailed(url, error));
        unawaited(ref.read(entitlementsViewModelProvider).refresh());
        if (!mounted) return;
        setState(() {
          _isQueueingSharedReel = false;
        });
        if (showConfirmation) {
          await openPaywall(context, entryPoint: PaywallEntryPoint.saveLimit);
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });
      unawaited(analytics.recordEnqueueFailed(url, error));
      if (showConfirmation) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                error,
                fallbackMessage: 'Could not start background save.',
              ),
              style: GoogleFonts.spaceMono(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: AppColors.destructive,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: AppColors.fg(context),
                width: AppTheme.borderWidth,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    WidgetsBinding.instance.removeObserver(this);
    _homeScrollController.dispose();
    _mediaIntentSub?.cancel();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    // Always drain shares captured while the app was backgrounded, regardless
    // of the content-refresh throttle below.
    unawaited(_drainPendingNativeShares());

    final now = DateTime.now();
    if (_lastResumeRefreshAt != null &&
        now.difference(_lastResumeRefreshAt!) < _resumeRefreshInterval) {
      return;
    }
    _lastResumeRefreshAt = now;

    unawaited(_refreshSavedContent());
  }

  // Native share receivers stash URLs when they cannot enqueue in the
  // background. We drain them here via the native bridge and enqueue using the
  // app's live, auto-refreshed Supabase session.
  Future<void> _drainPendingNativeShares() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final raw = await ShareHandoffService.instance.drainPendingShares();
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded) {
        final blob = entry?.toString().trim() ?? '';
        if (blob.isEmpty) continue;
        // Reset the per-payload dedupe so each pending share is processed.
        _lastHandledSharedPayload = null;
        // Pending entries are raw share blobs, so route them through the same
        // backend extraction path as a live share.
        await _handleSharedPayload(blob, showConfirmation: false);
      }
    } catch (e) {
      AppLogger.error('Pending share drain skipped: $e');
    }
  }

  /// The walkthrough runs before the permission prompts so the OS dialogs land
  /// with context ("we notify you when a save is ready") instead of on an empty
  /// home screen.
  Future<void> _runFirstRunFlow() async {
    await _maybeShowHowToGuide();
    await _maybePromptInitialPermissions();
  }

  Future<void> _maybeShowHowToGuide() async {
    if (!mounted) return;
    // The guide walks through a mobile share sheet and ships captures for both
    // platforms; there is nothing to show anywhere else.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    final guideService = HowToGuideService.instance;
    if (await guideService.hasSeenGuide(userId)) return;
    if (!mounted) return;

    await Navigator.of(context).push(howToUseRoute(isFirstRun: true));
    // Skipping still counts as seen — Profile keeps it reachable afterwards.
    await guideService.markGuideSeen(userId);
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
    final authService = ref.read(authServiceProvider);
    var attemptedPermissionPrompt = false;

    try {
      await LocationService.instance.requestPermission();
      attemptedPermissionPrompt = true;
    } catch (e) {
      AppLogger.error('Location permission setup skipped: $e');
    }

    try {
      await notificationService.initialize(requestPermissions: true);
      attemptedPermissionPrompt = true;
    } catch (e) {
      AppLogger.error('Notification permission setup skipped: $e');
    }

    final currentState = await notificationService.getPermissionState();
    final userId = authService.currentUser?.id;
    if (currentState == NotificationPermissionState.enabled &&
        userId != null &&
        userId.trim().isNotEmpty) {
      try {
        await ref
            .read(pushRegistrationServiceProvider)
            .register(userId: userId);
      } catch (e) {
        AppLogger.error('Push token registration skipped after prompt: $e');
      }
    }

    return attemptedPermissionPrompt;
  }

  Future<void> _syncPushTokenRegistrationIfPossible() async {
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    try {
      await ref.read(pushRegistrationServiceProvider).register(userId: userId);
    } catch (e) {
      AppLogger.error(
        'Push token registration skipped before share enqueue: $e',
      );
    }
  }

  void _openSearchFromHome() {
    setState(() {
      _currentIndex = 2;
      _searchFocusRequestId += 1;
    });
    _refreshSelectedContent(2);
  }

  Future<void> _scrollHomeToTop() async {
    if (!_homeScrollController.hasClients) return;
    await _homeScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _showHomeAtTop() {
    setState(() {
      _currentIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollHomeToTop());
    });
  }

  void _selectControlledTab(int index) {
    if (index == 0) {
      _showHomeAtTop();
      return;
    }
    _selectTab(index);
  }

  bool _isHomeScrolledDown() {
    if (!_homeScrollController.hasClients) return false;
    return _homeScrollController.offset > 8;
  }

  Future<void> _refreshSavedContent() async {
    await ref.read(entitlementsViewModelProvider).refresh(reloadContent: true);
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    _refreshSelectedContent(index);
  }

  void _refreshSelectedContent(int index) {
    if (index == 1) {
      unawaited(
        ref.read(mapViewModelProvider).loadMapReels(forceRefresh: true),
      );
    }
    if (index == 2) {
      unawaited(
        ref.read(discoverViewModelProvider).loadDiscover(forceRefresh: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0 && !_isHomeScrolledDown(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _showHomeAtTop();
          return;
        }
        if (_isHomeScrolledDown()) {
          unawaited(_scrollHomeToTop());
        }
      },
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: AppColors.bg(context),
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    HomeScreen(
                      onSearchTap: _openSearchFromHome,
                      scrollController: _homeScrollController,
                    ),
                    const MapScreen(),
                    DiscoverScreen(focusRequestId: _searchFocusRequestId),
                    const CollectionsScreen(),
                  ],
                ),
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    final bottomInset =
        MediaQuery.viewPaddingOf(context).bottom + _floatingNavBottomInset;

    return Positioned(
      left: _floatingNavHorizontalInset,
      right: _floatingNavHorizontalInset,
      bottom: bottomInset,
      child: Container(
        height: _floatingNavHeight,
        decoration: BoxDecoration(
          color: AppColors.bg(context),
          border: Border.all(
            color: AppColors.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.borderWidth),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  _navItems.length > 1
                      ? -1.0 + 2.0 * _currentIndex / (_navItems.length - 1)
                      : 0,
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / _navItems.length,
                  heightFactor: 1,
                  child: const ColoredBox(color: AppColors.yellow),
                ),
              ),
              Row(
                children: List.generate(_navItems.length, (i) {
                  return Expanded(child: _buildNavItem(i, _navItems[i]));
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _currentIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: GestureDetector(
        onTap: () => _selectTab(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Center(
            child: HugeIcon(
              icon: item.icon,
              color: isSelected ? AppColors.black : AppColors.fg(context),
              size: _navIconSize,
              strokeWidth: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
