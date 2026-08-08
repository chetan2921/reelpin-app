// Throwaway: checks the six platform icons are evenly spread. Delete after.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/home/home_screen.dart';
import 'package:reelpin/screens/onboarding/onboarding_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';

const _widths = [320.0, 360.0, 430.0];

/// Centre-to-centre gaps between consecutive icons.
List<double> _gaps(WidgetTester tester) {
  final centers = SourcePlatform.all
      .map(
        (p) => tester
            .getRect(find.bySemanticsLabel('${p.name} source platform'))
            .center
            .dx,
      )
      .toList();
  return [
    for (var i = 1; i < centers.length; i++) centers[i] - centers[i - 1],
  ];
}

void main() {
  for (final width in _widths) {
    testWidgets('onboarding icons evenly spread at ${width.toInt()}pt', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onContinue: () {})),
      );
      await tester.pump();

      final gaps = _gaps(tester);
      expect(gaps, hasLength(5));
      for (final gap in gaps) {
        expect((gap - gaps.first).abs() < 0.6, isTrue, reason: 'gaps: $gaps');
      }
      debugPrint('ONBOARDING ${width.toInt()}pt gaps: '
          '${gaps.map((g) => g.toStringAsFixed(1)).join(", ")}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty-state icons evenly spread at ${width.toInt()}pt', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(_StubApi()),
            authServiceProvider.overrideWithValue(_StubAuth()),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      final gaps = _gaps(tester);
      expect(gaps, hasLength(5));
      for (final gap in gaps) {
        expect((gap - gaps.first).abs() < 0.6, isTrue, reason: 'gaps: $gaps');
      }
      debugPrint('EMPTY STATE ${width.toInt()}pt gaps: '
          '${gaps.map((g) => g.toStringAsFixed(1)).join(", ")}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the SPOTS / IDEAS / TRIPS chips are gone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onContinue: () {})),
    );
    await tester.pumpAndSettle();

    for (final gone in ['SPOTS', 'IDEAS', 'TRIPS']) {
      expect(find.text(gone), findsNothing, reason: '$gone still rendered');
    }
    // The LOOK FOR rail survives.
    expect(find.text('LOOK FOR'), findsWidgets);
    expect(find.text('PLACES TO GO'), findsOneWidget);
    expect(find.text('THINGS TO BUY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StubApi extends ApiClient {
  _StubApi() : super(baseUrl: 'https://example.com');

  @override
  Future<ReelPage> getReelsPage({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 50,
    String? sort,
  }) async {
    return const ReelPage(
      reels: [],
      hasMore: false,
      totalCount: 0,
      limit: 25,
      offset: 0,
    );
  }
}

class _StubAuth extends AuthService {
  _StubAuth() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => User.fromJson({
    'id': 'user-123',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-04-20T00:00:00Z',
  });

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}
}
