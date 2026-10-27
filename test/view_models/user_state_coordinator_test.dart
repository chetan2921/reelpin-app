import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/data_models/map/map_bounds.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/view_models/collections_view_model.dart';
import 'package:reelpin/view_models/discover_view_model.dart';
import 'package:reelpin/view_models/entitlements_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/view_models/processing_jobs_view_model.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:reelpin/view_models/search_view_model.dart';
import 'package:reelpin/view_models/user_state_coordinator.dart';

import '../fixtures/api_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.chetanjain.reelpin/share_handoff');
  late _State state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    state = _State();
  });

  tearDown(() {
    state.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final slot in [
    ContentCacheKeys.reelsFirstPage,
    ContentCacheKeys.reelFilters,
    ContentCacheKeys.discoverOverview,
    ContentCacheKeys.mapOverview,
    ContentCacheKeys.entitlements,
  ]) {
    test('reset rejects a delayed cache read for $slot', () async {
      final gate = Completer<Map<String, dynamic>?>();
      state.cache.reads[slot] = gate;
      final pending = state.hydrate(slot);

      state.switchUser();
      gate.complete(_payload(slot));
      await pending;

      expect(state.hasPayload(slot), isFalse);
      expect(state.home.reels, isEmpty);
    });
  }

  test(
    'reset detaches an old library load before the next user loads',
    () async {
      final oldRead = Completer<Map<String, dynamic>?>();
      state.cache.reads[ContentCacheKeys.reelsFirstPage] = oldRead;
      final oldLoad = state.repository.loadInitialReels();

      state.switchUser();
      state.cache.reads.clear();
      final nextLoad = state.repository.loadInitialReels();
      await Future<void>.delayed(Duration.zero);
      expect(state.api.pageUsers, ['user-b']);
      oldRead.complete(_payload(ContentCacheKeys.reelsFirstPage));
      await Future.wait([oldLoad, nextLoad]);

      expect(state.api.pageUsers, ['user-b']);
      expect(state.repository.cachedReels, isEmpty);
      expect(state.repository.cacheUserId, 'user-b');
    },
  );

  test('reset rejects a delayed filter response', () async {
    final pending = state.filters.loadFilters();

    state.switchUser();
    state.api.filters.complete(ReelFiltersResponse.fromJson(_filters));
    await pending;

    expect(state.filters.response, isNull);
  });

  test(
    'reset rejects old entitlements without reloading the new library',
    () async {
      final pending = state.entitlements.refresh(reloadContent: true);

      state.switchUser();
      state.api.entitlements.complete(
        _entitlements('user-a', restricted: true),
      );
      await pending;

      expect(state.entitlements.response, isNull);
      expect(state.api.pageUsers, isEmpty);
      expect(state.api.mapLoads, 0);
    },
  );

  test('reset releases entitlements single-flight for the next user', () async {
    final oldResponse = state.api.entitlements;
    final oldLoad = state.entitlements.refresh();

    state.switchUser();
    state.api.entitlements = Completer<EntitlementsResponse>();
    final nextLoad = state.entitlements.refresh();
    expect(state.api.entitlementUsers, ['user-a', 'user-b']);
    oldResponse.complete(_entitlements('user-a', restricted: true));
    await oldLoad;
    expect(state.entitlements.isLoading, isTrue);
    state.api.entitlements.complete(_entitlements('user-b', restricted: true));
    await nextLoad;

    expect(state.entitlements.entitlement?.userId, 'user-b');
  });

  test('an old access-change continuation cannot clear the next map', () async {
    state.cache.reads[ContentCacheKeys.entitlements] = Completer()
      ..complete(_payload(ContentCacheKeys.entitlements));
    await state.entitlements.hydrateFromCache();
    final gate = Completer<void>();
    state.cache.invalidationGate = gate;
    final pending = state.entitlements.refresh();
    state.api.entitlements.complete(_entitlements('user-a', restricted: true));
    await Future<void>.delayed(Duration.zero);
    expect(state.cache.invalidations, ['content']);

    state.switchUser();
    final pin = _pin;
    state.api.mapResponse = MapResponse(mapItems: [pin]);
    await state.map.loadMapReels();
    gate.complete();
    await pending;

    expect(state.map.mapItems, [pin]);
    expect(state.entitlements.response, isNull);
  });

  test('reset rejects a delayed map pin result', () async {
    final pending = state.map.pinPlace(_place);

    state.switchUser();
    state.api.pin.complete(_pin);

    expect(await pending, isNull);
    expect(state.map.mapItems, isEmpty);
    expect(state.map.selectedMapItem, isNull);
    expect(state.cache.invalidations, isEmpty);
  });

  test('an old removal cannot remove the next user pin', () async {
    final pin = _pin;
    final pending = state.map.removeMapItem(pin);
    state.switchUser();
    state.api.mapResponse = MapResponse(mapItems: [pin]);
    await state.map.loadMapReels();

    state.api.removal.complete();

    expect(await pending, isFalse);
    expect(state.map.mapItems, [pin]);
    expect(state.cache.invalidations, isEmpty);
  });

  test('reset rejects old active processing jobs', () async {
    final pending = state.jobs.refresh();

    state.switchUser();
    state.api.jobs.complete([_job('old')]);
    await pending;

    expect(state.jobs.jobs, isEmpty);
  });

  test('reset releases job polling for the next account', () async {
    final oldResponse = state.api.jobs;
    final oldPoll = state.jobs.refresh();

    state.switchUser();
    state.api.jobs = Completer<List<ProcessingJob>>();
    final nextPoll = state.jobs.refresh();
    expect(state.api.jobLoads, 2);
    oldResponse.complete([_job('old')]);
    await oldPoll;
    state.api.jobs.complete([_job('new')]);
    await nextPoll;

    expect(state.jobs.jobs.map((job) => job.id), ['new']);
  });
}

const _filters = <String, dynamic>{
  'categories': [
    {'category': 'Travel', 'count': 7},
  ],
  'total_count': 7,
};

Map<String, dynamic> _payload(String slot) {
  switch (slot) {
    case ContentCacheKeys.reelsFirstPage:
      return ApiV2Fixture('reel_page').body;
    case ContentCacheKeys.reelFilters:
      return _filters;
    case ContentCacheKeys.discoverOverview:
      return {'recent_saves': ApiV2Fixture('reel_page').body['reels']};
    case ContentCacheKeys.mapOverview:
      return ApiV2Fixture('map_pins').body;
    default:
      return {
        'user_id': 'user-a',
        'current_entitlement': {'plan': 'pro'},
      };
  }
}

EntitlementsResponse _entitlements(String userId, {bool restricted = false}) =>
    EntitlementsResponse.fromJson({
      'user_id': userId,
      'current_entitlement': {'plan': 'pro', 'restricted': restricted},
    });

MapItem get _pin =>
    MapResponse.fromJson(ApiV2Fixture('map_pins').body).mapItems.single;

const _place = MapPlaceSearchResult(
  resultType: 'google_place',
  googlePlaceId: 'place-id',
  displayTitle: 'Private place',
  displayAddress: '',
  placeName: 'Private place',
  placeTypes: [],
  canPin: true,
);

ProcessingJob _job(String id) => ProcessingJob(id: id, status: 'processing');

class _State {
  final api = _Api();
  final auth = _Auth();
  final cache = _Cache();
  late final repository = ReelRepository(api, auth, contentCache: cache);
  late final home = HomeViewModel(repository);
  late final filters = ReelFiltersViewModel(repository, cache: cache);
  late final discover = DiscoverViewModel(repository, cache: cache);
  late final map = MapViewModel(api, api, cache: cache);
  late final search = SearchViewModel(repository);
  late final collections = CollectionsViewModel(api, cache: cache);
  late final entitlements = EntitlementsViewModel(
    api,
    auth,
    repository,
    home,
    map,
    filters,
    discover,
    search,
    cache: cache,
  );
  late final jobs = ProcessingJobsViewModel(repository)..setForeground(false);
  late final coordinator = UserStateCoordinator(
    collectionsViewModel: collections,
    searchViewModel: search,
    reelFiltersViewModel: filters,
    mapViewModel: map,
    homeViewModel: home,
    discoverViewModel: discover,
    reelRepository: repository,
    entitlementsViewModel: entitlements,
    processingJobsViewModel: jobs,
  );

  void switchUser() {
    auth.userId = 'user-b';
    coordinator.reset();
  }

  Future<void> hydrate(String slot) {
    switch (slot) {
      case ContentCacheKeys.reelsFirstPage:
        return repository.hydrateCache();
      case ContentCacheKeys.reelFilters:
        return filters.hydrateFromCache();
      case ContentCacheKeys.discoverOverview:
        return discover.hydrateFromCache();
      case ContentCacheKeys.mapOverview:
        return map.hydrateFromCache();
      default:
        return entitlements.hydrateFromCache();
    }
  }

  bool hasPayload(String slot) {
    switch (slot) {
      case ContentCacheKeys.reelsFirstPage:
        return repository.cachedReels.isNotEmpty;
      case ContentCacheKeys.reelFilters:
        return filters.response != null;
      case ContentCacheKeys.discoverOverview:
        return discover.discover != null;
      case ContentCacheKeys.mapOverview:
        return map.mapItems.isNotEmpty;
      default:
        return entitlements.response != null;
    }
  }

  void dispose() {
    jobs.dispose();
    home.dispose();
    filters.dispose();
    discover.dispose();
    map.dispose();
    search.dispose();
    collections.dispose();
    entitlements.dispose();
    repository.dispose();
  }
}

class _Cache implements ContentCache {
  final reads = <String, Completer<Map<String, dynamic>?>>{};
  final invalidations = <String>[];
  Completer<void>? invalidationGate;

  @override
  Future<Map<String, dynamic>?> read(String key) async => reads[key]?.future;

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> payload, {
    String? expectedUserId,
  }) async {}

  @override
  Future<void> invalidate(String key) async => invalidations.add(key);

  @override
  Future<void> invalidateContent() async {
    invalidations.add('content');
    await invalidationGate?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthService {
  _Auth() : super(ProfileService());
  String userId = 'user-a';

  @override
  User? get currentUser => User.fromJson({
    'id': userId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-10-28T00:00:00Z',
  });
}

class _Api extends ApiClient {
  final filters = Completer<ReelFiltersResponse>();
  var entitlements = Completer<EntitlementsResponse>();
  var jobs = Completer<List<ProcessingJob>>();
  final pin = Completer<MapItem>();
  final removal = Completer<void>();
  final pageUsers = <String?>[];
  final entitlementUsers = <String>[];
  int mapLoads = 0;
  int jobLoads = 0;
  MapResponse mapResponse = const MapResponse(mapItems: []);

  @override
  Future<ReelPage> getReelsPage({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? cursor,
    int limit = 50,
  }) async {
    pageUsers.add(userId);
    return const ReelPage(reels: [], limit: 25);
  }

  @override
  Future<ReelFiltersResponse> getReelFilters({
    String? platform,
    String? category,
    String? subcategory,
  }) => filters.future;

  @override
  Future<EntitlementsResponse> getAccountEntitlements({
    required String userId,
  }) {
    entitlementUsers.add(userId);
    return entitlements.future;
  }

  @override
  Future<MapResponse> getMapData({
    required MapBounds bounds,
    String? category,
  }) async {
    mapLoads += 1;
    return mapResponse;
  }

  @override
  Future<LibraryStats> getLibraryStats() async => const LibraryStats(
    totalReels: 0,
    totalPinnedLocations: 0,
    totalTags: 0,
    totalCategories: 0,
    totalSubcategories: 0,
  );

  @override
  Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken}) =>
      pin.future;

  @override
  Future<void> removeMapItem(String mapItemId) => removal.future;

  @override
  Future<List<ProcessingJob>> listProcessingJobs({
    bool activeOnly = true,
    int limit = 20,
  }) {
    jobLoads += 1;
    return jobs.future;
  }
}
