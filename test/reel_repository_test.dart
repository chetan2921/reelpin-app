import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel.dart';
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
}

class _FakeReelStore extends ReelStore {
  @override
  Future<ReelCacheSnapshot?> loadCachedReels({required String userId}) async {
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
}

class _FakeApiService extends ApiService {
  _FakeApiService() : super(baseUrl: 'https://example.com');

  final List<String> deletedReelIds = [];

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
