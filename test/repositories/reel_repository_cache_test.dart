import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory directory;
  late ContentCache cache;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('reel_repository_cache');
    cache = ContentCache.forTesting(
      directory: directory,
      userIdProvider: () => 'user-123',
    );
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  Future<void> seedCache() {
    return cache.write(ContentCacheKeys.reelsFirstPage, {
      'reels': [_cachedReelJson],
      'has_more': true,
      'total_count': 9,
      'limit': 25,
      'offset': 0,
      'next_offset': 25,
    });
  }

  test('hydrateCache restores the last saved page', () async {
    await seedCache();
    final repository = ReelRepository(
      _PendingApiService(),
      _FakeAuthService(),
      contentCache: cache,
    );

    await repository.hydrateCache();

    expect(repository.cachedReels.map((reel) => reel.id), ['cached-reel']);
    expect(repository.totalCount, 9);
    expect(repository.hasMoreReels, isTrue);
    expect(repository.cacheUserId, 'user-123');
  });

  test('restored reels are on screen before the network responds', () async {
    await seedCache();
    final api = _PendingApiService();
    final repository = ReelRepository(
      api,
      _FakeAuthService(),
      contentCache: cache,
    );

    final load = repository.loadInitialReels(forceRefresh: true);
    await pumpEventQueue();

    // Still waiting on the request, but the list already has content.
    expect(repository.cachedReels.map((reel) => reel.id), ['cached-reel']);

    api.complete();
    await load;

    expect(repository.cachedReels.map((reel) => reel.id), ['live-reel']);
    expect(repository.totalCount, 1);
  });

  test('a filtered load does not restore the unfiltered snapshot', () async {
    await seedCache();
    final api = _PendingApiService();
    final repository = ReelRepository(
      api,
      _FakeAuthService(),
      contentCache: cache,
    );

    final load = repository.loadInitialReels(
      forceRefresh: true,
      category: 'Food',
    );
    await pumpEventQueue();

    expect(repository.cachedReels, isEmpty);

    api.complete();
    await load;
  });

  test('hydrateCache leaves live data alone once it has arrived', () async {
    await seedCache();
    final api = _PendingApiService();
    final repository = ReelRepository(
      api,
      _FakeAuthService(),
      contentCache: cache,
    );

    api.complete();
    await repository.loadInitialReels(forceRefresh: true);
    expect(repository.cachedReels.map((reel) => reel.id), ['live-reel']);

    // A late or repeated hydration must not put the snapshot back on top.
    await repository.hydrateCache();

    expect(repository.cachedReels.map((reel) => reel.id), ['live-reel']);
  });

  test('clearCache re-arms hydration for the next signed-in user', () async {
    await seedCache();
    final repository = ReelRepository(
      _PendingApiService(),
      _FakeAuthService(),
      contentCache: cache,
    );

    await repository.hydrateCache();
    expect(repository.hasHydratedCache, isTrue);

    repository.clearCache();

    expect(repository.hasHydratedCache, isFalse);
    expect(repository.cachedReels, isEmpty);
  });

  test('deleting a reel drops the saved snapshot', () async {
    await seedCache();
    final api = _PendingApiService()..complete();
    final repository = ReelRepository(
      api,
      _FakeAuthService(),
      contentCache: cache,
    );

    await repository.deleteReel('cached-reel');

    expect(await cache.read(ContentCacheKeys.reelsFirstPage), isNull);
  });
}

const _cachedReelJson = <String, dynamic>{
  'id': 'cached-reel',
  'user_id': 'user-123',
  'url': 'https://example.com/cached',
  'title': 'Cached',
  'category': 'Food',
};

class _PendingApiService extends ApiClient {
  _PendingApiService() : super(baseUrl: 'https://example.com');

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

  @override
  Future<void> deleteReel(String reelId) async {}

  void complete() {
    if (_completer.isCompleted) return;
    _completer.complete(
      const ReelPage(
        reels: [_liveReel],
        hasMore: false,
        totalCount: 1,
        limit: 25,
        offset: 0,
      ),
    );
  }
}

const _liveReel = Reel(
  id: 'live-reel',
  userId: 'user-123',
  url: 'https://example.com/live',
  title: 'Live',
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
