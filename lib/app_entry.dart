import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/app_shell/authenticated_shell.dart';
import 'package:reelpin/screens/splash/splash_screen.dart';
import 'package:reelpin/services/app_update_service.dart';
import 'package:reelpin/screens/auth/auth_screen.dart';
import 'package:reelpin/screens/onboarding/onboarding_screen.dart';
import 'package:reelpin/services/sharing/pending_deep_link.dart';
import 'package:reelpin/services/sharing/shared_collection_prefetch.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry>
    with WidgetsBindingObserver {
  static const _onboardingCompletedKey = 'app_entry_onboarding_completed_v1';

  bool _hasCompletedOnboarding = false;
  bool _isLoadingOnboardingState = true;
  bool _hasStartedContentLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppUpdateService.checkForImmediateUpdate());
    _startCollectionLaunch();
    _loadOnboardingState();
    _startContentLoad();
  }

  /// Restores the cached library and starts the first refresh.
  ///
  /// The session is restored from local storage before `runApp`, so a returning
  /// user is already known here — a build ahead of [AuthenticatedShell]. That
  /// head start is what lets the shell paint cached cards rather than an empty
  /// grid on its first frame.
  ///
  /// Both calls de-duplicate internally, so the shell repeating them on mount
  /// costs nothing.
  void _startContentLoad() {
    if (_hasStartedContentLoad) return;
    if (!ref.read(sessionViewModelProvider).isAuthenticated) return;
    _hasStartedContentLoad = true;

    // Deferred a frame: refresh() notifies its listeners synchronously, which
    // must not happen while this widget is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(userStateCoordinatorProvider).hydrate());
      unawaited(
        ref.read(entitlementsViewModelProvider).refresh(reloadContent: true),
      );
    });
  }

  /// A launch from a collection link asked for one specific screen, so its
  /// fetch starts here rather than waiting for the shell to mount.
  void _startCollectionLaunch() {
    final link = PendingDeepLink.pendingCollectionLink;
    if (link == null) return;
    // An invite has to be redeemed before there is anything to show, and that
    // is the shell's job.
    if (link.isInvite) return;
    SharedCollectionPrefetch.start(
      link.token,
      () => ref.read(collectionsHttpProvider).getSharedCollection(link.token),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppUpdateService.checkForImmediateUpdate());
    }
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hasCompletedOnboarding = prefs.getBool(_onboardingCompletedKey) ?? false;
      _isLoadingOnboardingState = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    if (!mounted) return;
    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionVm = ref.watch(sessionViewModelProvider);

    if (sessionVm.isAuthenticated) {
      // Also covers signing in mid-session, when initState ran before there
      // was a user to load anything for.
      _startContentLoad();
      // Straight through: the session was restored from local storage before
      // runApp, and the shell's own screens each know how to show a cached or
      // loading state. Holding a splash in front of them buys nothing that the
      // home grid's shimmer does not already cover, and costs the user the
      // whole wait.
      return const AuthenticatedShell();
    }

    // Signed out; let the next sign-in start its own load.
    _hasStartedContentLoad = false;

    // The one thing here that is not known synchronously, and it picks between
    // two different screens, so there is nothing correct to draw until it
    // lands. A single preferences read, so this is a frame or two at most.
    if (_isLoadingOnboardingState) return const SplashScreen();

    if (!_hasCompletedOnboarding) {
      return OnboardingScreen(
        onContinue: () {
          unawaited(_completeOnboarding());
        },
      );
    }
    return const AuthScreen();
  }
}
