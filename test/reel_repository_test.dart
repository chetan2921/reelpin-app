import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/models/reel_page.dart';
import 'package:reelpin/models/search_response.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/models/user_entitlement.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/api_service.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('deleteReel refreshes fetched cache from backend', () async {
    final api = _FakeApiService();
    final repository = ReelRepository(api, _FakeAuthService());

    await repository.loadInitialReels(forceRefresh: true);
    await repository.deleteReel(_reelA.id);

    expect(repository.cachedReels.map((reel) => reel.id), [_reelB.id]);
    expect(api.deletedReelIds, [_reelA.id]);
  });

  test('search returns only backend results', () async {
    final api = _FakeApiService(searchResponse: _emptySearchResponse);
    final repository = ReelRepository(api, _FakeAuthService());

    final response = await repository.search('gym');

    expect(response.results, isEmpty);
    expect(response.total, 0);
  });

  test(
    'ignores stale reel response after authenticated user changes',
    () async {
      final auth = _MutableAuthService('user-a');
      final api = _DelayedApiService();
      final repository = ReelRepository(api, auth);

      final load = repository.loadInitialReels(forceRefresh: true);
      await Future<void>.delayed(Duration.zero);
      auth.userId = 'user-b';
      api.complete();
      await load;

      expect(repository.cachedReels, isEmpty);
      expect(repository.cacheUserId, isNull);
    },
  );
}

class _FakeApiService extends ApiService {
  _FakeApiService({this.searchResponse})
    : super(baseUrl: 'https://example.com');

  final List<Reel> _serverReels = [_reelA, _reelB];
  final List<String> deletedReelIds = [];
  final SearchResponse? searchResponse;

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
    return ReelPage(
      reels: List.unmodifiable(_serverReels),
      hasMore: false,
      totalCount: _serverReels.length,
      limit: 25,
      offset: 0,
    );
  }

  @override
  Future<void> deleteReel(String reelId) async {
    deletedReelIds.add(reelId);
    _serverReels.removeWhere((reel) => reel.id == reelId);
  }

  @override
  Future<SearchResponse> searchReels(
    String query, {
    String userId = 'default-user',
    String? category,
    String? subcategory,
    int limit = 5,
    http.Client? client,
  }) async {
    return searchResponse ??
        SearchResponse(
          query: query,
          results: const [],
          total: 0,
          searchMode: SearchMode.keyword,
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

class _MutableAuthService extends AuthService {
  _MutableAuthService(this.userId) : super(ProfileService());

  String userId;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => User.fromJson({
    'id': userId,
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

class _DelayedApiService extends ApiService {
  _DelayedApiService()
    : super(
        baseUrl: 'https://example.com',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

  final _completer = Completer<ReelPage>();

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
  }) {
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      const ReelPage(
        reels: [_reelA],
        hasMore: false,
        totalCount: 1,
        limit: 25,
        offset: 0,
      ),
    );
  }
}

const _reelA = Reel(
  id: 'reel-a',
  userId: 'user-123',
  url: 'https://example.com/a',
  title: 'A',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Food',
  subCategory: 'Meals',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-20T00:00:00Z',
);

const _reelB = Reel(
  id: 'reel-b',
  userId: 'user-123',
  url: 'https://example.com/b',
  title: 'B',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Travel',
  subCategory: 'Trips',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-19T00:00:00Z',
);

const _emptySearchResponse = SearchResponse(
  query: 'gym',
  results: [],
  total: 0,
  searchMode: SearchMode.rag,
);
