import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/home/home_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';

late _FakeApiClient api;

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Filters'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => api = _FakeApiClient());

  testWidgets('lists every social the user has actually saved from', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    expect(find.text('SOCIAL'), findsOneWidget);
    expect(find.bySemanticsLabel('ALL, 12 saved'), findsOneWidget);
    expect(find.bySemanticsLabel('INSTAGRAM, 8 saved'), findsOneWidget);
    expect(find.bySemanticsLabel('YOUTUBE, 4 saved'), findsOneWidget);
    // Nothing is saved from Pinterest, so it must not be offered.
    expect(find.bySemanticsLabel('PINTEREST, 0 saved'), findsNothing);
  });

  testWidgets('picking a social previews its count without a request', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    expect(find.text('APPLY / 12 REELS'), findsOneWidget);
    final requestsBefore = api.reelsPageCalls;

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();

    expect(find.text('APPLY / 4 REELS'), findsOneWidget);
    expect(api.reelsPageCalls, requestsBefore);
  });

  testWidgets('applying a social filters the reels request', (tester) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY / 4 REELS'));
    await tester.pumpAndSettle();

    expect(api.lastPlatform, 'youtube');
    expect(api.lastCategory, isNull);
  });

  testWidgets('the category dropdown only offers the social\'s categories', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    // YouTube holds Travel and Comedy; Instagram's Movies is not reachable.
    expect(find.byType(DropdownMenuItem<String>), findsNWidgets(2));

    await tester.tap(find.text('TRAVEL').last);
    await tester.pumpAndSettle();

    // 3 is YouTube's Travel count — the 5 across every platform would mean the
    // platform scope had been lost.
    expect(find.text('APPLY / 3 REELS'), findsOneWidget);
  });

  testWidgets('subcategories are scoped to the social too', (tester) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRAVEL').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FOOD GUIDES').last);
    await tester.pumpAndSettle();

    expect(find.text('APPLY / 3 REELS'), findsOneWidget);

    await tester.tap(find.text('APPLY / 3 REELS'));
    await tester.pumpAndSettle();

    expect(api.lastPlatform, 'youtube');
    expect(api.lastCategory, 'Travel');
    expect(api.lastSubcategory, 'Food Guides');
  });

  testWidgets('switching social clears a category that does not carry over', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    await tester.tap(find.bySemanticsLabel('INSTAGRAM, 8 saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('MOVIES').last);
    await tester.pumpAndSettle();
    expect(find.text('APPLY / 6 REELS'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();

    // Movies has nothing on YouTube, so the sheet falls back to the whole
    // platform rather than previewing an empty result.
    expect(find.text('APPLY / 4 REELS'), findsOneWidget);
  });

  testWidgets('re-tapping the active social clears it', (tester) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();
    expect(find.text('APPLY / 4 REELS'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('YOUTUBE, 4 saved'));
    await tester.pumpAndSettle();

    expect(find.text('APPLY / 12 REELS'), findsOneWidget);
  });

  testWidgets('RESET drops the selection', (tester) async {
    await _pumpHome(tester);
    await _openSheet(tester);

    await tester.tap(find.bySemanticsLabel('INSTAGRAM, 8 saved'));
    await tester.pumpAndSettle();
    expect(find.text('APPLY / 8 REELS'), findsOneWidget);

    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();

    expect(find.text('APPLY / 12 REELS'), findsOneWidget);
  });

  testWidgets('the header button reports an active filter', (tester) async {
    await _pumpHome(tester);
    expect(find.bySemanticsLabel('Filters'), findsOneWidget);

    await _openSheet(tester);
    await tester.tap(find.bySemanticsLabel('INSTAGRAM, 8 saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY / 8 REELS'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Filters, active'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');

  int reelsPageCalls = 0;
  String? lastPlatform;
  String? lastCategory;
  String? lastSubcategory;

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
    reelsPageCalls += 1;
    lastPlatform = platform;
    lastCategory = category;
    lastSubcategory = subcategory;
    return ReelPage(
      reels: [
        Reel.fromJson(const {
          'id': 'reel-1',
          'user_id': 'user-123',
          'url': 'https://example.com/one',
          'title': 'One',
          'category': 'Movies',
        }),
      ],
      hasMore: false,
      totalCount: 1,
      limit: limit,
      offset: 0,
    );
  }

  @override
  Future<ReelFiltersResponse> getReelFilters({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
  }) async {
    return ReelFiltersResponse.fromJson(_treeJson);
  }
}

const _treeJson = <String, dynamic>{
  'total_count': 12,
  'top_platform': 'instagram',
  'selected_preview_count': 12,
  'platforms': [
    {
      'platform': 'instagram',
      'label': 'Instagram',
      'count': 8,
      'top_category': 'Movies',
      'categories': [
        {
          'category': 'Movies',
          'label': 'Movies',
          'count': 6,
          'subcategories': [
            {'name': 'Trailers', 'label': 'Trailers', 'count': 4},
          ],
        },
        {
          'category': 'Travel',
          'label': 'Travel',
          'count': 2,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 2},
          ],
        },
      ],
    },
    {
      'platform': 'youtube',
      'label': 'YouTube',
      'count': 4,
      'top_category': 'Travel',
      'categories': [
        {
          'category': 'Travel',
          'label': 'Travel',
          'count': 3,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 3},
          ],
        },
        {
          'category': 'Comedy',
          'label': 'Comedy',
          'count': 1,
          'subcategories': [
            {'name': 'Stand Up', 'label': 'Stand Up', 'count': 1},
          ],
        },
      ],
    },
  ],
  'categories': [
    {
      'category': 'Movies',
      'label': 'Movies',
      'count': 6,
      'subcategories': [
        {'name': 'Trailers', 'label': 'Trailers', 'count': 4},
      ],
    },
    {
      'category': 'Travel',
      'label': 'Travel',
      'count': 5,
      'subcategories': [
        {'name': 'Food Guides', 'label': 'Food Guides', 'count': 5},
      ],
    },
    {
      'category': 'Comedy',
      'label': 'Comedy',
      'count': 1,
      'subcategories': [
        {'name': 'Stand Up', 'label': 'Stand Up', 'count': 1},
      ],
    },
  ],
};

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

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
