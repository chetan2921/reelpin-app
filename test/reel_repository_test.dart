import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reelpin/models/search_response.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/models/user_entitlement.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/api_service.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:reelpin/services/reel_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'deleteReel removes entries from fetched cache without fixed-length errors',
    () async {
      final store = _FakeReelStore();
      final api = _FakeApiService();
      final repository = ReelRepository(api, store, _FakeAuthService());

      await repository.loadInitialReels(forceRefresh: true);
      await repository.deleteReel(_reelA.id);

      expect(repository.cachedReels.map((reel) => reel.id), [_reelB.id]);
      expect(api.deletedReelIds, [_reelA.id]);
    },
  );

  test(
    'search returns local matches when backend returns no results',
    () async {
      final store = _FakeReelStore(cachedReels: const [_gymReel]);
      final api = _FakeApiService(searchResponse: _emptySearchResponse);
      final repository = ReelRepository(api, store, _FakeAuthService());

      final results = await repository.search('gym');

      expect(results.map((result) => result.reel.id), [_gymReel.id]);
    },
  );
}

class _FakeReelStore extends ReelStore {
  _FakeReelStore({this.cachedReels = const []});

  final List<Reel> cachedReels;

  @override
  Future<ReelCacheSnapshot?> loadCachedReels({required String userId}) async {
    if (cachedReels.isNotEmpty) {
      return ReelCacheSnapshot(
        reels: cachedReels,
        nextOffset: cachedReels.length,
        hasMore: false,
        lastFetchedAt: DateTime.now(),
      );
    }
    return null;
  }

  @override
  Future<void> saveCachedReels({
    required String userId,
    required List<Reel> reels,
    required int nextOffset,
    required bool hasMore,
    required DateTime lastFetchedAt,
  }) async {}

  @override
  Future<void> removeCachedReel({
    required String userId,
    required String reelId,
  }) async {}

  @override
  Future<List<Reel>> searchCachedReels({
    required String userId,
    required String query,
    String? category,
    String? subcategory,
    int limit = 48,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    return cachedReels
        .where((reel) {
          return [
            reel.title,
            reel.summary,
            reel.caption,
            reel.transcript,
            reel.category,
            reel.subCategory,
            reel.keyFacts.join(' '),
            reel.peopleMentioned.join(' '),
            reel.actionableItems.join(' '),
          ].join(' ').toLowerCase().contains(normalizedQuery);
        })
        .take(limit)
        .toList(growable: false);
  }
}

class _FakeApiService extends ApiService {
  _FakeApiService({this.searchResponse})
    : super(baseUrl: 'https://example.com');

  final List<String> deletedReelIds = [];
  final SearchResponse? searchResponse;

  @override
  Future<List<Reel>> getReels({
    String? userId,
    String? category,
    int limit = 50,
  }) async {
    return const [_reelA, _reelB];
  }

  @override
  Future<void> deleteReel(String reelId) async {
    deletedReelIds.add(reelId);
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

const _gymReel = Reel(
  id: 'gym-1',
  userId: 'user-123',
  url: 'https://example.com/gym',
  title: 'Gym pull day',
  summary: 'Back and biceps workout',
  caption: 'Gym exercises for strength training',
  transcript: 'Start with pull ups and rows',
  category: 'Fitness',
  subCategory: 'Gym Exercises',
  keyFacts: ['Pull ups', 'Rows', 'Progressive overload'],
  locations: [],
  peopleMentioned: [],
  actionableItems: ['Try 3 sets of 10 reps'],
  createdAt: '2026-04-18T00:00:00Z',
);

const _emptySearchResponse = SearchResponse(
  query: 'gym',
  results: [],
  total: 0,
  searchMode: SearchMode.rag,
);
