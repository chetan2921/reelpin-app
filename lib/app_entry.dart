import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/app_shell/authenticated_shell.dart';
import 'package:reelpin/screens/splash/splash_screen.dart';
import 'package:reelpin/services/app_update_service.dart';
import 'package:reelpin/screens/auth/auth_screen.dart';
import 'package:reelpin/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry>
    with WidgetsBindingObserver {
  static const _minimumSplashDuration = Duration(milliseconds: 1600);
  static const _onboardingCompletedKey = 'app_entry_onboarding_completed_v1';

  bool _hasCompletedSplash = false;
  bool _hasCompletedOnboarding = false;
  bool _isLoadingOnboardingState = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppUpdateService.checkForImmediateUpdate());
    _holdSplash();
    _loadOnboardingState();
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

  Future<void> _holdSplash() async {
    await Future<void>.delayed(_minimumSplashDuration);
    if (!mounted) return;
    setState(() {
      _hasCompletedSplash = true;
    });
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

    if (!_hasCompletedSplash ||
        sessionVm.isBootstrapping ||
        _isLoadingOnboardingState) {
      return const SplashScreen();
    }

    if (!sessionVm.isAuthenticated) {
      if (!_hasCompletedOnboarding) {
        return OnboardingScreen(
          onContinue: () {
            unawaited(_completeOnboarding());
          },
        );
      }
      return const AuthScreen();
    }

    return const AuthenticatedShell();
  }
}
