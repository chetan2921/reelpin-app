import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/main.dart';
import 'package:reelpin/providers/app_providers.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:reelpin/viewmodels/session_viewmodel.dart';

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
      find.text('TURN SAVED REELS INTO PLANS YOU CAN ACTUALLY USE.'),
      findsOneWidget,
    );

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE TO LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('WELCOME BACK TO YOUR REEL ARCHIVE.'), findsOneWidget);

    await _pumpAppEntry(tester);
    expect(find.text('WELCOME BACK TO YOUR REEL ARCHIVE.'), findsOneWidget);
    expect(
      find.text('TURN SAVED REELS INTO PLANS YOU CAN ACTUALLY USE.'),
      findsNothing,
    );
  });
}

Future<void> _pumpAppEntry(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionViewModelProvider.overrideWith(
          (ref) => SessionViewModel(_FakeAuthService()),
        ),
      ],
      child: const MaterialApp(home: AppEntry()),
    ),
  );
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
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
