import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/app/app_entry.dart';
import 'package:reelpin/app/providers.dart';
import 'package:reelpin/app/reelpin_app.dart';
import 'package:reelpin/core/network/api_service.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/features/auth/data/profile_service.dart';
import 'package:reelpin/features/auth/presentation/session_viewmodel.dart';

void main() {
  testWidgets('App renders setup screen when Supabase is not configured', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: ReelPinApp(isSupabaseConfigured: false)),
    );
    expect(find.text('SUPABASE SETUP REQUIRED'), findsOneWidget);
  });

  testWidgets('onboarding completion persists across cold starts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpAppEntry(tester);
    expect(
      find.text('SAVE INSTAGRAM, YOUTUBE, AND X FINDS INTO PLANS YOU CAN USE.'),
      findsOneWidget,
    );

    await tester.tap(find.text('NEXT'));
    await _pumpPageTransition(tester);
    await tester.tap(find.text('NEXT'));
    await _pumpPageTransition(tester);
    await tester.tap(find.text('CONTINUE TO LOGIN'));
    await tester.pump();

    expect(find.text('WELCOME BACK TO YOUR REEL ARCHIVE.'), findsOneWidget);

    await _pumpAppEntry(tester);
    expect(find.text('WELCOME BACK TO YOUR REEL ARCHIVE.'), findsOneWidget);
    expect(
      find.text('SAVE INSTAGRAM, YOUTUBE, AND X FINDS INTO PLANS YOU CAN USE.'),
      findsNothing,
    );
  });

  testWidgets('checks for an Android update on startup and resume', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1170, 2532);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    const channel = MethodChannel('de.ffuf.in_app_update/methods');
    var checkCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method != 'checkForUpdate') return null;
      checkCalls += 1;
      return <String, Object?>{
        'updateAvailability': 1,
        'immediateAllowed': false,
        'immediateAllowedPreconditions': <int>[],
        'flexibleAllowed': false,
        'flexibleAllowedPreconditions': <int>[],
        'availableVersionCode': 15,
        'installStatus': 0,
        'packageName': 'com.chetanjain.reelpin',
        'clientVersionStalenessDays': null,
        'updatePriority': 0,
      };
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    await _pumpAppEntry(tester);
    expect(checkCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(checkCalls, 2);
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _pumpPageTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pumpAppEntry(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionViewModelProvider.overrideWith(
          (ref) => _FakeSessionViewModel(_FakeAuthService()),
        ),
      ],
      child: const MaterialApp(home: AppEntry()),
    ),
  );
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final hasOnboarding = find
        .text('SAVE INSTAGRAM, YOUTUBE, AND X FINDS INTO PLANS YOU CAN USE.')
        .evaluate()
        .isNotEmpty;
    final hasAuth = find
        .text('WELCOME BACK TO YOUR REEL ARCHIVE.')
        .evaluate()
        .isNotEmpty;
    if (hasOnboarding || hasAuth) return;
  }
}

class _FakeSessionViewModel extends SessionViewModel {
  _FakeSessionViewModel(AuthService authService)
    : super(
        authService,
        () => ApiService(baseUrl: 'https://example.com'),
        () => ApiService(baseUrl: 'https://example.com'),
      );

  @override
  bool get isBootstrapping => false;
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}
}
