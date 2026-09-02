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
import 'package:reelpin/services/sharing/collection_link.dart';
import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';
import 'package:reelpin/services/sharing/linkrunner_service.dart';
import 'package:reelpin/services/sharing/pending_deep_link.dart';
import 'package:reelpin/services/sharing/share_handoff_service.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/screens/home/home_screen.dart';
import 'package:reelpin/screens/map/map_screen.dart';
import 'package:reelpin/screens/paywall/paywall_screen.dart';
import 'package:reelpin/screens/splash/splash_screen.dart';
import 'package:reelpin/screens/discover/discover_screen.dart';
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

  int _currentIndex = _AppTab.home;
  StreamSubscription? _mediaIntentSub;
  AppLinks? _appLinks;
  StreamSubscription? _deepLinkSub;
  CollectionLink? _launchLink;
  bool _hasRoutedLaunchLink = false;
  Uri? _launchUriReplayGuard;
  bool _isQueueingSharedReel = false;
  String? _lastHandledSharedPayload;
  bool _isCheckingInitialPermissions = false;
  int _searchFocusRequestId = 0;
  DateTime? _lastResumeRefreshAt;
  final ScrollController _homeScrollController = ScrollController();

  static const _navItems = [
    _NavItem(icon: HugeIcons.strokeRoundedHome04, label: 'HOME'),
    _NavItem(icon: HugeIcons.strokeRoundedLocation03, label: 'MAP'),
    _NavItem(icon: HugeIcons.strokeRoundedFolderPin, label: 'SAVED'),
    _NavItem(icon: HugeIcons.strokeRoundedDiscoverSquare, label: 'DISCOVER'),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_selectControlledTab);
    WidgetsBinding.instance.addObserver(this);
    _initSharingIntent();
    // Claimed before anything awaits: the Linkrunner-gated path below resumes
    // on a microtask, which is still ahead of this frame, and would otherwise
    // take the link and open it with a transition.
    final launchUri = PendingDeepLink.pendingUri;
    _launchLink = PendingDeepLink.takeCollectionLink();
    if (_launchLink != null) {
      _hasRoutedLaunchLink = true;
      _launchUriReplayGuard = launchUri;
    }
    unawaited(_initCollectionDeepLinks());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Opened at the end of the shell's first frame. Pushing any earlier would
      // mark the root navigator dirty while it is still building.
      final launchLink = _launchLink;
      if (launchLink != null) unawaited(_openLaunchLink(launchLink));
      unawaited(_runFirstRunFlow());
      unawaited(_drainPendingNativeShares());
    });
  }

  Future<void> _initCollectionDeepLinks() async {
    // Init first: a link arriving before this completes resolves as a plain
    // URL, which is correct for direct /c/ links but loses Linkrunner ones.
    await LinkrunnerService.instance.init();

    _appLinks = AppLinks();
    try {
      // Skipped entirely when the launch link was already claimed above, or
      // asking again would open the same collection a second time.
      if (!_hasRoutedLaunchLink) {
        // Taken from bootstrap, which captured it before auth gating could
        // consume it. Falls back to asking directly for warm-start safety.
        final initial =
            PendingDeepLink.take() ?? await _appLinks!.getInitialLink();
        if (initial != null) {
          unawaited(_handleIncomingUri(initial));
        } else {
          // No launch URL. This may still be the first open after installing
          // from a share link, where the destination only exists as attribution.
          unawaited(_handleDeferredLink());
        }
      }
    } catch (_) {}
    _deepLinkSub = _appLinks!.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
      onError: (_) {},
    );
  }

  Future<void> _handleDeferredLink() async {
    final deferred = await LinkrunnerService.instance.deferredLink();
    if (deferred != null) _routeCollectionUri(deferred);
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    // Android hands the launch intent to the link stream once it starts
    // listening, so the URL the app opened with arrives here a second time and
    // would stack another copy of the collection on the one already open. Only
    // the replay is dropped: tapping the same link again later is a real
    // request to reopen it.
    if (_launchUriReplayGuard == uri) {
      _launchUriReplayGuard = null;
      return;
    }
    _routeCollectionUri(await LinkrunnerService.instance.resolve(uri));
  }

  void _routeCollectionUri(Uri uri) {
    final link = CollectionLink.parse(uri);
    if (link != null) _routeCollectionLink(link);
  }

  /// Holds the splash until the launch link has somewhere to send the user.
  ///
  /// A share link can be opened straight away. An invite has to be redeemed
  /// over the network first, and releasing the shell for the length of that
  /// round trip is what made a tapped invite look like it opened Home and then
  /// moved somewhere else seconds later. Whether it succeeds or fails, the
  /// shell is released at the end: on failure the user lands on Home with the
  /// snackbar, which is where they would have been anyway.
  Future<void> _openLaunchLink(CollectionLink link) async {
    try {
      if (link.isInvite) {
        await _acceptCollectionInvite(link.token, animate: false);
      } else {
        unawaited(
          _openSharedCollection(link.token, animate: false, url: link.url),
        );
      }
    } finally {
      if (mounted) setState(() => _launchLink = null);
    }
  }

  void _routeCollectionLink(CollectionLink link, {bool animate = true}) {
    unawaited(
      AnalyticsService.log(
        AnalyticsEvent.collectionLinkOpened,
        parameters: {'kind': link.isInvite ? 'invite' : 'share'},
      ),
    );
    if (link.isInvite) {
      unawaited(_acceptCollectionInvite(link.token));
    } else {
      unawaited(
        _openSharedCollection(link.token, animate: animate, url: link.url),
      );
    }
  }

  Future<void> _openSharedCollection(
    String token, {
    bool animate = true,
    String? url,
  }) async {
    if (!mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(sharedCollectionRoute(token, animate: animate, url: url));
  }

  Future<void> _acceptCollectionInvite(
    String token, {
    bool animate = true,
  }) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final joined = await ref
          .read(collectionsViewModelProvider)
          .acceptInvite(token);
      if (joined != null && mounted) {
        // Not awaited: pushing settles the destination, but the future only
        // completes when the user pops back out of it.
        unawaited(
          Navigator.of(
            context,
            rootNavigator: true,
          ).push(collectionDetailRoute(joined.id, animate: animate)),
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
    List<String> collectionIds = const [],
  }) async {
    final normalizedPayload = payload.trim();
    if (normalizedPayload.isEmpty) return;

    final analytics = ref.read(shareFlowAnalyticsServiceProvider);
    unawaited(analytics.recordShareDetected(normalizedPayload));
    unawaited(AnalyticsService.log(AnalyticsEvent.shareReceived));
    if (_lastHandledSharedPayload == normalizedPayload) {
      unawaited(analytics.recordDuplicateShareSkipped(normalizedPayload));
      unawaited(AnalyticsService.log(AnalyticsEvent.shareDuplicateSkipped));
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
      await _enqueueSharedReel(
        resolvedUrl,
        showConfirmation: showConfirmation,
        collectionIds: collectionIds,
      );
    } catch (error, stack) {
      unawaited(analytics.recordEnqueueFailed(normalizedPayload, error));
      unawaited(
        AnalyticsService.log(
          AnalyticsEvent.reelSaveFailed,
          parameters: {'reason': 'resolve_failed'},
        ),
      );
      unawaited(AnalyticsService.recordError(error, stack));
    }
  }

  Future<void> _enqueueSharedReel(
    String url, {
    required bool showConfirmation,
    List<String> collectionIds = const [],
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
      await homeVm.enqueueReelProcessing(url, collectionIds: collectionIds);
      unawaited(_refreshSavedContent());

      if (!mounted) return;
      setState(() {
        _isQueueingSharedReel = false;
      });
      unawaited(analytics.recordEnqueueSucceeded(url));
      unawaited(AnalyticsService.log(AnalyticsEvent.reelSaveSucceeded));

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
    } catch (error, stack) {
      if (error is ApiException && error.isMonthlyReelLimitReached) {
        unawaited(analytics.recordEnqueueFailed(url, error));
        unawaited(
          AnalyticsService.log(
            AnalyticsEvent.reelSaveFailed,
            parameters: {'reason': 'monthly_limit'},
          ),
        );
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
      unawaited(
        AnalyticsService.log(
          AnalyticsEvent.reelSaveFailed,
          parameters: {'reason': 'enqueue_failed'},
        ),
      );
      unawaited(AnalyticsService.recordError(error, stack));
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
        // Native stashes {raw_payload_text, collection_ids}. Anything already
        // on disk from an older build is a bare string, and still has to drain.
        final blob =
            (entry is Map ? entry['raw_payload_text'] : entry)
                ?.toString()
                .trim() ??
            '';
        if (blob.isEmpty) continue;
        final collectionIds = entry is Map
            ? (entry['collection_ids'] as List?)
                      ?.map((id) => id.toString())
                      .where((id) => id.isNotEmpty)
                      .toList(growable: false) ??
                  const <String>[]
            : const <String>[];
        // Reset the per-payload dedupe so each pending share is processed.
        _lastHandledSharedPayload = null;
        // Pending entries are raw share blobs, so route them through the same
        // backend extraction path as a live share.
        await _handleSharedPayload(
          blob,
          showConfirmation: false,
          collectionIds: collectionIds,
        );
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

    // Armed by onboarding, so only a fresh install is owed the walkthrough. A
    // returning user goes straight to their reels; skipping still counts, and
    // the empty state and Profile both keep the guide reachable.
    if (!await HowToGuideService.instance.takePendingGuide()) return;
    if (!mounted) return;

    await Navigator.of(context).push(howToUseRoute(isFirstRun: true));
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
      _currentIndex = _AppTab.discover;
      _searchFocusRequestId += 1;
    });
    _refreshSelectedContent(_AppTab.discover);
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
      _currentIndex = _AppTab.home;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollHomeToTop());
    });
  }

  void _selectControlledTab(int index) {
    if (index == _AppTab.home) {
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
    // Detail screens are pushed onto the root navigator, above the shell, so
    // switching tabs used to change the tab underneath while the pushed screen
    // stayed on top — tapping SAVED appeared to reopen the last collection.
    // Tapping any tab returns to that tab's root, including when it is already
    // selected, which is also the expected "tap again to go back" behaviour.
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    setState(() {
      _currentIndex = index;
    });
    _refreshSelectedContent(index);
  }

  void _refreshSelectedContent(int index) {
    if (index == _AppTab.map) {
      unawaited(
        ref.read(mapViewModelProvider).loadMapReels(forceRefresh: true),
      );
    }
    if (index == _AppTab.discover) {
      unawaited(
        ref.read(discoverViewModelProvider).loadDiscover(forceRefresh: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A launch link is opened at the end of this first frame, so until then the
    // shell holds nothing the user asked for. Painting Home in that gap is what
    // made a tapped link look like it opened the wrong screen and then moved;
    // staying on the splash instead makes the collection the first thing shown.
    if (_launchLink != null) return const SplashScreen();

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
                    const CollectionsScreen(),
                    DiscoverScreen(focusRequestId: _searchFocusRequestId),
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
