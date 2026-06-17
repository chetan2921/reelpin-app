import 'dart:async';
import 'dart:convert';

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
import '../services/location_service.dart';
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
      'app_shell_initial_permissions_prompted_v6';
  static const coachCompletedKey = 'app_shell_coach_completed_v1';
  static const _shareConfirmationDuration = Duration(milliseconds: 1400);
  static const _resumeRefreshInterval = Duration(minutes: 5);

  int _currentIndex = 0;
  int _coachStepIndex = 0;
  StreamSubscription? _mediaIntentSub;
  bool _isQueueingSharedReel = false;
  String? _lastHandledSharedPayload;
  bool _isCheckingInitialPermissions = false;
  bool _isLoadingCoachState = true;
  bool _showCoach = false;
  int _searchFocusRequestId = 0;
  int _folderSelectionRequestId = 0;
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
      unawaited(_drainPendingNativeShares());
      unawaited(_loadCoachState());
    });
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
      await _enqueueSharedReel(resolvedUrl, showConfirmation: true);
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
                  color: AppTheme.neonGreen,
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: AppTheme.fg(context),
                  ),
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
        final url = entry?.toString().trim() ?? '';
        if (url.isEmpty) continue;
        // Reset the per-payload dedupe so each pending URL is processed.
        _lastHandledSharedPayload = null;
        await _enqueueSharedReel(url, showConfirmation: false);
      }
    } catch (e) {
      debugPrint('Pending share drain skipped: $e');
    }
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
    var attemptedPermissionPrompt = false;

    try {
      await LocationService.instance.requestPermission();
      attemptedPermissionPrompt = true;
    } catch (e) {
      debugPrint('Location permission setup skipped: $e');
    }

    try {
      await notificationService.initialize(requestPermissions: true);
      attemptedPermissionPrompt = true;
    } catch (e) {
      debugPrint('Notification permission setup skipped: $e');
    }

    final currentState = await notificationService.getPermissionState();
    final userId = authService.currentUser?.id;
    if (currentState == NotificationPermissionState.enabled &&
        userId != null &&
        userId.trim().isNotEmpty) {
      try {
        final token = await notificationService.getFcmToken();
        if (token != null && token.trim().isNotEmpty) {
          await ShareHandoffService.instance.syncPushToken(
            token: token,
            platform: notificationService.currentPlatform,
          );
          await apiService.registerPushToken(
            userId: userId,
            token: token,
            platform: notificationService.currentPlatform,
          );
        }
      } catch (e) {
        debugPrint('Push token registration skipped after prompt: $e');
      }
    }

    return attemptedPermissionPrompt;
  }

  Future<void> _loadCoachState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(coachCompletedKey) ?? false;
    if (!mounted) return;
    setState(() {
      _isLoadingCoachState = false;
      _showCoach = !completed;
      _coachStepIndex = 0;
      if (_showCoach) {
        _currentIndex = _coachSteps.first.tabIndex;
      }
    });
  }

  Future<void> _completeCoach() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(coachCompletedKey, true);
    if (!mounted) return;
    setState(() {
      _showCoach = false;
      _coachStepIndex = 0;
    });
  }

  void _nextCoachStep() {
    if (_coachStepIndex >= _coachSteps.length - 1) {
      unawaited(_completeCoach());
      return;
    }
    final nextIndex = _coachStepIndex + 1;
    setState(() {
      _coachStepIndex = nextIndex;
      _currentIndex = _coachSteps[nextIndex].tabIndex;
    });
    _refreshSelectedContent(_coachSteps[nextIndex].tabIndex);
  }

  void _openCoach() {
    Navigator.pop(context);
    setState(() {
      _showCoach = true;
      _coachStepIndex = 0;
      _currentIndex = _coachSteps.first.tabIndex;
    });
    _refreshSelectedContent(_coachSteps.first.tabIndex);
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

      await ShareHandoffService.instance.syncPushToken(
        token: token.trim(),
        platform: notificationService.currentPlatform,
      );
      await apiService.registerPushToken(
        userId: userId,
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
    _refreshSelectedContent(2);
  }

  void _startFolderSelectionFromDiscover() {
    setState(() {
      _currentIndex = 0;
      _folderSelectionRequestId += 1;
      _showCoach = false;
    });
    _refreshSelectedContent(0);
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
      canPop: _currentIndex == 0 && !_showCoach,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showCoach) {
          unawaited(_completeCoach());
          return;
        }
        if (_currentIndex == 0) return;
        _selectTab(0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              color: AppTheme.bg(context),
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  HomeScreen(
                    onSearchTap: _openSearchFromHome,
                    isActive: _currentIndex == 0,
                    folderSelectionRequestId: _folderSelectionRequestId,
                  ),
                  const MapScreen(),
                  SearchScreen(
                    focusRequestId: _searchFocusRequestId,
                    onCreateFolderTap: _startFolderSelectionFromDiscover,
                    onShowAppGuide: _openCoach,
                  ),
                ],
              ),
            ),
            if (_showCoach && !_isLoadingCoachState)
              _CoachOverlay(
                step: _coachSteps[_coachStepIndex],
                stepNumber: _coachStepIndex + 1,
                totalSteps: _coachSteps.length,
                onNext: _nextCoachStep,
                onSkip: () => unawaited(_completeCoach()),
              ),
          ],
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
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
      onTap: () => _selectTab(index),
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

const _coachSteps = [
  _CoachStep(
    tabIndex: 0,
    icon: Icons.home_rounded,
    title: 'HOME',
    body:
        'YOUR SAVED REELS LIVE HERE. TAP A CARD TO OPEN IT, OR LONG PRESS TO SELECT REELS.',
    accent: AppTheme.yellow,
  ),
  _CoachStep(
    tabIndex: 0,
    icon: Icons.ios_share,
    title: 'SAVE REELS',
    body:
        'SHARE AN INSTAGRAM REEL TO REELPIN FROM YOUR PHONE. WE SAVE IT AND PROCESS IT IN THE BACKGROUND.',
    accent: AppTheme.neonGreen,
  ),
  _CoachStep(
    tabIndex: 2,
    icon: Icons.folder_rounded,
    title: 'FOLDERS',
    body:
        'GROUP IMPORTANT REELS INTO YOUR OWN FOLDERS. START FROM DISCOVER OR LONG PRESS REELS ON HOME.',
    accent: AppTheme.cyan,
  ),
  _CoachStep(
    tabIndex: 1,
    icon: Icons.map_rounded,
    title: 'MAP',
    body:
        'REELS WITH PLACES SHOW UP ON THE MAP SO YOU CAN FIND TRIPS, FOOD, AND LOCATIONS AGAIN.',
    accent: AppTheme.hotPink,
  ),
  _CoachStep(
    tabIndex: 2,
    icon: Icons.explore_rounded,
    title: 'DISCOVER',
    body:
        'SEARCH YOUR SAVES, FILTER BY DATE, OPEN FOLDERS, AND BROWSE BY CATEGORY FROM HERE.',
    accent: AppTheme.blue,
  ),
];

class _CoachStep {
  const _CoachStep({
    required this.tabIndex,
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final int tabIndex;
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
}

class _CoachOverlay extends StatelessWidget {
  const _CoachOverlay({
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final _CoachStep step;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final isLastStep = stepNumber == totalSteps;

    return Positioned.fill(
      child: Material(
        color: AppTheme.black.withAlpha(150),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.inset(20),
              layout.gap(16),
              layout.inset(20),
              layout.gap(88),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: AppTheme.brutalCard(
                  context,
                  color: AppTheme.bg(context),
                ),
                padding: EdgeInsets.all(layout.inset(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: layout.inset(42),
                          height: layout.inset(42),
                          decoration: AppTheme.brutalBox(
                            context,
                            color: step.accent,
                            shadow: false,
                          ),
                          child: Icon(
                            step.icon,
                            color: step.accent.computeLuminance() > 0.5
                                ? AppTheme.black
                                : AppTheme.white,
                            size: layout.inset(22),
                          ),
                        ),
                        SizedBox(width: layout.inset(12)),
                        Expanded(
                          child: Text(
                            step.title,
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.fg(context),
                              fontSize: layout.font(18),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Text(
                          '$stepNumber/$totalSteps',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.textSec(context),
                            fontSize: layout.font(11),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: layout.gap(14)),
                    Text(
                      step.body,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: layout.font(12),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: layout.gap(16)),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onSkip,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.inset(6),
                              vertical: layout.gap(10),
                            ),
                            child: Text(
                              'SKIP',
                              style: GoogleFonts.spaceMono(
                                color: AppTheme.textSec(context),
                                fontSize: layout.font(12),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onNext,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.inset(18),
                              vertical: layout.gap(11),
                            ),
                            decoration: AppTheme.brutalBox(
                              context,
                              color: step.accent,
                              shadow: true,
                            ),
                            child: Text(
                              isLastStep ? 'DONE' : 'NEXT',
                              style: GoogleFonts.spaceMono(
                                color: step.accent.computeLuminance() > 0.5
                                    ? AppTheme.black
                                    : AppTheme.white,
                                fontSize: layout.font(12),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
