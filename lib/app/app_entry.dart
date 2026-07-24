import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reelpin/app/providers.dart';
import 'package:reelpin/app/shell/authenticated_shell.dart';
import 'package:reelpin/app/splash_screen.dart';
import 'package:reelpin/core/platform/app_update_service.dart';
import 'package:reelpin/features/auth/presentation/auth_screen.dart';
import 'package:reelpin/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  static const _minimumSplashDuration = Duration(milliseconds: 1600);
  static const _onboardingCompletedKey = 'app_entry_onboarding_completed_v1';

  bool _hasCompletedSplash = false;
  bool _hasCompletedOnboarding = false;
  bool _isLoadingOnboardingState = true;

  @override
  void initState() {
    super.initState();
    unawaited(AppUpdateService.checkForImmediateUpdate());
    _holdSplash();
    _loadOnboardingState();
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
