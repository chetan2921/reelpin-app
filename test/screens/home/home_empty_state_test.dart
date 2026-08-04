import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/home/home_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';

/// The empty state hands its children an unbounded height and pushes the source
/// strip to the bottom with a [Spacer], so the strip is the part that breaks
/// when a platform is added. These are the widths worth pinning.
const _sizes = <String, Size>{
  'small phone': Size(320, 568),
  'common phone': Size(360, 800),
  'large phone': Size(430, 932),
};

Future<void> _pumpEmptyHome(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_EmptyApiClient()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('Home empty state source strip', () {
    for (final entry in _sizes.entries) {
      testWidgets('renders every platform on a ${entry.key}', (tester) async {
        await _pumpEmptyHome(tester, entry.value);

        for (final platform in SourcePlatform.all) {
          final finder = find.bySemanticsLabel(
            '${platform.name} source platform',
          );
          expect(
            finder,
            findsOneWidget,
            reason: '${platform.name} is missing from the home hint',
          );

          final rect = tester.getRect(finder);
          expect(
            rect.left >= 0 && rect.right <= entry.value.width,
            isTrue,
            reason:
                '${platform.name} sits outside the '
                '${entry.value.width.toInt()}pt viewport at $rect',
          );
        }

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('names every platform in the caption', (tester) async {
      await _pumpEmptyHome(tester, _sizes['common phone']!);

      expect(
        find.text(
          'SHARE FROM INSTAGRAM, YOUTUBE, X, PINTEREST, REDDIT, OR LINKEDIN',
        ),
        findsOneWidget,
      );
    });
  });
}

class _EmptyApiClient extends ApiClient {
  _EmptyApiClient() : super(baseUrl: 'https://example.com');

  @override
  Future<ReelPage> getReelsPage({
    String? userId,
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
