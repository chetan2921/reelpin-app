import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/mock_collection_chat_http.dart';
import 'package:reelpin/http/mock_collections_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/components/chat/chat_composer.dart';
import 'package:reelpin/screens/collections/partials/collection_chat_panel.dart';
import 'package:reelpin/screens/collections/collection_detail_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => User.fromJson({
    'id': 'user-a',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-04-20T00:00:00Z',
  });

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();
}

void main() {
  late Directory directory;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('collection_detail_tabs');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  /// `c-empty` is an owned collection with no reels, so the grid never asks
  /// for a network image — which a widget test cannot serve.
  ///
  /// [gridOnly] loads just the SAVED grid, as when a collection is tapped
  /// there, and returns once the screen has mounted.
  Future<CollectionsViewModel> pumpDetail(
    WidgetTester tester, {
    required bool offerChat,
    bool gridOnly = false,
  }) async {
    final collectionsHttp = MockCollectionsHttp();
    final collections = CollectionsViewModel(
      collectionsHttp,
      cache: ContentCache.forTesting(
        directory: directory,
        userIdProvider: () => 'user-a',
      ),
    );
    // Loaded for real before the screen mounts: the cache sits on dart:io,
    // which does not complete inside a widget test's fake clock.
    await tester.runAsync(
      () => gridOnly
          ? collections.loadCollections()
          : collections.loadCollectionDetail('c-empty'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          collectionsHttpProvider.overrideWithValue(collectionsHttp),
          collectionsViewModelProvider.overrideWith((ref) => collections),
          collectionChatHttpProvider.overrideWithValue(
            MockCollectionChatHttp(stageDelay: Duration.zero),
          ),
        ],
        child: MaterialApp(
          home: CollectionDetailScreen(
            collectionId: 'c-empty',
            offerChat: offerChat,
          ),
        ),
      ),
    );
    if (gridOnly) return collections;
    // The screen refetches over the cached detail; the mock answers after
    // ~450ms.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return collections;
  }

  testWidgets(
    'opening from the grid seeds the collection without modifying a provider '
    'mid-build',
    (tester) async {
      final collections = await pumpDetail(
        tester,
        offerChat: false,
        gridOnly: true,
      );

      // Riverpod throws when initState notifies a provider's listeners; in
      // release that throw is skipped and the tree may build inconsistently.
      expect(tester.takeException(), isNull);
      expect(collections.isDetailPlaceholder('c-empty'), isTrue);
    },
  );

  testWidgets('CHATS swaps the pins for the shared thread, PINS swaps back', (
    tester,
  ) async {
    await pumpDetail(tester, offerChat: true);

    expect(find.byType(CollectionChatPanel), findsNothing);

    await tester.tap(find.text('CHATS'));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionChatPanel), findsOneWidget);
    // An owner can ask.
    expect(find.byType(ChatComposer), findsOneWidget);

    await tester.tap(find.text('PINS'));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionChatPanel), findsNothing);
  });

  testWidgets('no tab bar at all when chat is off', (tester) async {
    await pumpDetail(tester, offerChat: false);

    expect(find.text('CHATS'), findsNothing);
    expect(find.byType(CollectionChatPanel), findsNothing);
  });
}
