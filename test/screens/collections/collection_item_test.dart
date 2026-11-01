import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/components/reels/reel_card.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/mock_collections_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/collections/collection_detail_screen.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

void main() {
  final cases = <String, (String, bool, bool)>{
    'a collection owner opens a member save': ('member', false, true),
    'a collection owner opens their own save': ('owner', false, false),
    'an anonymous link stays read-only': ('owner', true, true),
  };
  for (final entry in cases.entries) {
    testWidgets(entry.key, (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = <String, dynamic>{
        'id': 'reel-1',
        'reel_id': 'reel-1',
        'user_id': entry.value.$1,
        'title': 'The collection item',
        'summary': 'A useful saved item',
        'url': 'https://example.com/item',
        'category': 'Food',
        'subcategory': 'Cafes',
        'key_facts': ['Member-specific fact'],
        'transcript': 'The full transcript',
      };
      final collections = _CollectionItems(item);
      final requestedReels = <String>[];
      final api = ApiClient(
        baseUrl: 'https://api.example',
        accessTokenProvider: () => 'test-token',
        client: MockClient((request) async {
          if (request.url.path == '/api/v2/reels/reel-1') {
            requestedReels.add(request.url.path);
            return http.Response(jsonEncode(item), 200);
          }
          return http.Response('{}', 503);
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_SignedInOwner()),
            apiClientProvider.overrideWithValue(api),
            collectionsHttpProvider.overrideWithValue(collections),
            collectionsViewModelProvider.overrideWith(
              (_) => CollectionsViewModel(collections),
            ),
          ],
          child: MaterialApp(
            home: CollectionDetailScreen(
              collectionId: 'collection-1',
              sharedToken: entry.value.$2 ? 'shared-token' : null,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ReelCard), findsOneWidget);
      await tester.tap(find.byType(ReelCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final screen = tester.widget<ReelDetailScreen>(
        find.byType(ReelDetailScreen),
      );
      expect(screen.readOnly, entry.value.$3);
      expect(screen.reel.keyFacts, ['Member-specific fact']);
      expect(screen.reel.transcript, 'The full transcript');
      expect(
        requestedReels,
        entry.value.$3 ? isEmpty : ['/api/v2/reels/reel-1'],
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

class _CollectionItems extends MockCollectionsHttp {
  _CollectionItems(this.item);

  final Map<String, dynamic> item;

  CollectionDetail get detail => CollectionDetail.fromJson({
    'collection': {
      'id': 'collection-1',
      'name': 'Shared collection',
      'role': 'owner',
      'item_count': 1,
    },
    'items': [item],
    'can_edit': true,
  });

  @override
  Future<CollectionDetail> getCollectionDetail(
    String collectionId, {
    int limit = 25,
    String? cursor,
  }) async => detail;

  @override
  Future<CollectionDetail> getSharedCollection(
    String token, {
    int limit = 25,
    String? cursor,
  }) async => detail;
}

class _SignedInOwner extends AuthService {
  _SignedInOwner() : super(ProfileService());

  @override
  User? get currentUser => const User(
    id: 'owner',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  @override
  Session? get currentSession => null;
}
