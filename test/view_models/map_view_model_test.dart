import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/map/map_bounds.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/http/map_http.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/discover/search_response.dart';
import 'package:reelpin/data_models/discover/search_result.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/view_models/search_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'home filters reload from backend without filtering local reels',
    () async {
      final repository = _FakeReelRepository.empty(
        cachedReels: const [_travelReel, _foodReel],
      );
      final viewModel = HomeViewModel(repository);

      viewModel.applyFilters(category: 'Travel', subcategory: 'Coffee Shops');
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastCategory, 'Travel');
      expect(repository.lastSubcategory, 'Coffee Shops');
      expect(viewModel.reels.map((reel) => reel.id), ['travel-1', 'food-1']);
    },
  );

  test('map removal clears selected map item state', () async {
    final repository = _FakeReelRepository.empty(
      mapResponse: const MapResponse(mapItems: [_travelMapItem]),
    );
    final viewModel = MapViewModel(repository);
    await viewModel.loadMapReels(forceRefresh: true);
    viewModel.selectMapItem(_travelMapItem);

    viewModel.removeReel(_travelReel.id);

    expect(viewModel.mapItems, isEmpty);
    expect(viewModel.selectedMapItem, isNull);
  });

  test('search removal drops deleted reels from results', () async {
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async => const SearchResponse(
            query: 'coffee',
            results: [
              SearchResult(reel: _travelReel, relevanceScore: 0.9),
              SearchResult(reel: _foodReel, relevanceScore: 0.8),
            ],
            total: 2,
            searchMode: SearchMode.rag,
          ),
    );
    final viewModel = SearchViewModel(repository);

    await viewModel.search('coffee');
    viewModel.removeReel(_travelReel.id);

    expect(viewModel.results.map((result) => result.reel.id), ['food-1']);
  });

  test('map place search stores backend results', () async {
    final repository = _FakeReelRepository.empty(
      onMapSearch:
          ({
            required String query,
            String? category,
            String? sessionToken,
          }) async => const MapPlaceSearchResponse(
            query: 'brew',
            searchMode: 'existing',
            total: 1,
            results: [
              MapPlaceSearchResult(
                resultType: 'existing',
                sourceType: 'reel',
                mapItem: _travelMapItem,
                displayTitle: 'Brew Lab',
                displayAddress: 'Brew Lab',
                placeName: 'Brew Lab',
                placeTypes: [],
                canPin: false,
              ),
            ],
          ),
    );
    final viewModel = MapViewModel(repository);

    await viewModel.searchMapPlaces('brew');

    expect(repository.lastMapSearchQuery, 'brew');
    expect(repository.lastMapSearchSessionToken, isNotEmpty);
    expect(viewModel.placeSearchResults.single.isExisting, isTrue);
    expect(viewModel.placeSearchResults.single.mapItem?.markerId, _locationId);
  });

  test('pinPlace upserts and selects manual map pin', () async {
    final repository = _FakeReelRepository.empty(pinnedMapItem: _manualMapItem);
    final viewModel = MapViewModel(repository);

    final item = await viewModel.pinPlace(
      const MapPlaceSearchResult(
        resultType: 'google',
        googlePlaceId: 'place-1',
        displayTitle: 'Manual Cafe',
        displayAddress: '12 Market Street',
        placeName: 'Manual Cafe',
        placeTypes: ['cafe'],
        canPin: true,
      ),
    );

    expect(item?.mapItemId, 'manual:pin-1');
    expect(viewModel.mapItems.map((item) => item.mapItemId), ['manual:pin-1']);
    expect(viewModel.selectedMapItem?.mapItemId, 'manual:pin-1');
    expect(viewModel.totalPinnedLocations, 1);
  });

  test('removeMapItem deletes a manual pin through its manual: id', () async {
    final repository = _FakeReelRepository.empty(
      mapResponse: const MapResponse(
        mapItems: [_travelMapItem, _manualMapItem],
      ),
    );
    final viewModel = MapViewModel(repository);
    await viewModel.loadMapReels(forceRefresh: true);
    viewModel.selectMapItem(_manualMapItem);

    final success = await viewModel.removeMapItem(_manualMapItem);

    expect(success, isTrue);
    expect(repository.removedMapItemIds, ['manual:pin-1']);
    expect(viewModel.mapItems.map((item) => item.mapItemId), [_locationId]);
    expect(viewModel.selectedMapItem, isNull);
    expect(viewModel.totalPinnedLocations, 1);
  });

  test('removeMapItem hides a content pin through its location id', () async {
    final repository = _FakeReelRepository.empty(
      mapResponse: const MapResponse(mapItems: [_travelMapItem]),
    );
    final viewModel = MapViewModel(repository);
    await viewModel.loadMapReels(forceRefresh: true);

    final success = await viewModel.removeMapItem(_travelMapItem);

    expect(success, isTrue);
    expect(repository.removedMapItemIds, [_locationId]);
    expect(viewModel.mapItems, isEmpty);
  });

  test('removeMapItem sends nothing for a pin it may not change', () async {
    final repository = _FakeReelRepository.empty();
    final viewModel = MapViewModel(repository);

    final success = await viewModel.removeMapItem(_lockedMapItem);

    expect(success, isFalse);
    expect(repository.removedMapItemIds, isEmpty);
  });

  group('viewport', () {
    test('loads the whole world before the camera reports a box', () async {
      final repository = _FakeReelRepository.empty();
      final viewModel = MapViewModel(repository);

      await viewModel.loadMapReels();

      expect(repository.mapDataCalls.single.bounds, MapBounds.world);
      expect(repository.mapDataCalls.single.category, isNull);
    });

    testWidgets('queries only the last box of quick camera settles', (
      tester,
    ) async {
      final repository = _FakeReelRepository.empty();
      final viewModel = MapViewModel(repository);

      viewModel.updateViewport(_goa);
      await tester.pump(const Duration(milliseconds: 100));
      viewModel.updateViewport(_mumbai);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.mapDataCalls, isEmpty);

      await tester.pump(MapViewModel.viewportDebounce);

      expect(repository.mapDataCalls.map((call) => call.bounds), [_mumbai]);
      viewModel.dispose();
    });

    testWidgets('ignores a box with no height', (tester) async {
      final repository = _FakeReelRepository.empty();
      final viewModel = MapViewModel(repository);

      viewModel.updateViewport(
        const MapBounds(south: 0, west: 0, north: 0, east: 0),
      );
      await tester.pump(MapViewModel.viewportDebounce);

      expect(repository.mapDataCalls, isEmpty);
      viewModel.dispose();
    });

    testWidgets('a category filter is sent for the current box', (
      tester,
    ) async {
      final repository = _FakeReelRepository.empty();
      final viewModel = MapViewModel(repository);
      viewModel.updateViewport(_goa);
      await tester.pump(MapViewModel.viewportDebounce);

      viewModel.filterByCategory('Travel');
      await tester.pump();

      final last = repository.mapDataCalls.last;
      expect(last.bounds, _goa);
      expect(last.category, 'Travel');
      viewModel.dispose();
    });

    test('an older answer does not replace a newer one', () async {
      final goaPins = Completer<MapResponse>();
      final repository = _FakeReelRepository.empty(
        onGetMapData: (bounds, category) => bounds == _goa
            ? goaPins.future
            : Future.value(const MapResponse(mapItems: [_manualMapItem])),
      );
      final viewModel = MapViewModel(repository);

      viewModel.updateViewport(_goa);
      final goaLoad = viewModel.loadMapReels();
      viewModel.updateViewport(_mumbai);
      await viewModel.loadMapReels();
      goaPins.complete(const MapResponse(mapItems: [_travelMapItem]));
      await goaLoad;

      expect(viewModel.mapItems.single.mapItemId, 'manual:pin-1');
      expect(viewModel.isLoading, isFalse);
      viewModel.dispose();
    });

    test('the same query in flight is not sent twice', () async {
      final pins = Completer<MapResponse>();
      final repository = _FakeReelRepository.empty(
        onGetMapData: (_, _) => pins.future,
      );
      final viewModel = MapViewModel(repository);

      final first = viewModel.loadMapReels();
      final second = viewModel.loadMapReels();
      pins.complete(const MapResponse(mapItems: []));
      await Future.wait([first, second]);

      expect(repository.mapDataCalls, hasLength(1));
    });

    test('keeps the selected pin when a new box leaves it out', () async {
      final repository = _FakeReelRepository.empty(
        mapResponse: const MapResponse(mapItems: []),
      );
      final viewModel = MapViewModel(repository);
      viewModel.selectMapItem(_travelMapItem);

      await viewModel.loadMapReels();

      expect(viewModel.selectedMapItem, _travelMapItem);
    });
  });

  group('nearby', () {
    test('returns the nearest pins for a point', () async {
      final repository = _FakeReelRepository.empty(
        nearbyResponse: const MapResponse(mapItems: [_travelMapItem]),
      );
      final viewModel = MapViewModel(repository);

      final nearby = await viewModel.nearbyMapItems(12.9, 77.6);

      expect(nearby.single.mapItemId, _locationId);
      expect(repository.nearbyCalls, [(12.9, 77.6)]);
    });

    test(
      'answers empty when the lookup fails, so recenter still works',
      () async {
        final repository = _FakeReelRepository.empty(nearbyFails: true);
        final viewModel = MapViewModel(repository);

        final nearby = await viewModel.nearbyMapItems(12.9, 77.6);

        expect(nearby, isEmpty);
      },
    );
  });
}

class _FakeReelRepository extends ReelRepository implements MapHttp {
  _FakeReelRepository({required this.onSearch})
    : cachedReels = const [],
      mapResponse = null,
      onGetMapData = null,
      nearbyResponse = null,
      nearbyFails = false,
      onMapSearch = null,
      pinnedMapItem = null,
      super(ApiClient(baseUrl: 'https://example.com'), _FakeAuthService());

  _FakeReelRepository.empty({
    this.cachedReels = const [],
    this.mapResponse,
    this.onGetMapData,
    this.nearbyResponse,
    this.nearbyFails = false,
    this.onMapSearch,
    this.pinnedMapItem,
  }) : onSearch = _emptySearch,
       super(ApiClient(baseUrl: 'https://example.com'), _FakeAuthService());

  final Future<SearchResponse> Function({
    required String query,
    String? category,
    String? subcategory,
  })
  onSearch;

  final Future<MapPlaceSearchResponse> Function({
    required String query,
    String? category,
    String? sessionToken,
  })?
  onMapSearch;

  @override
  final List<Reel> cachedReels;

  final MapResponse? mapResponse;
  final Future<MapResponse> Function(MapBounds bounds, String? category)?
  onGetMapData;
  final MapResponse? nearbyResponse;
  final bool nearbyFails;
  final MapItem? pinnedMapItem;
  final List<({MapBounds bounds, String? category})> mapDataCalls = [];
  final List<(double, double)> nearbyCalls = [];
  final List<String> removedMapItemIds = [];
  String? lastCategory;
  String? lastSubcategory;
  String? lastMapSearchQuery;
  String? lastMapSearchCategory;
  String? lastMapSearchSessionToken;

  static Future<SearchResponse> _emptySearch({
    required String query,
    String? category,
    String? subcategory,
  }) async => SearchResponse(
    query: query,
    results: const [],
    total: 0,
    searchMode: SearchMode.keyword,
  );

  @override
  Future<void> loadInitialReels({
    bool forceRefresh = false,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
  }) async {
    lastCategory = category;
    lastSubcategory = subcategory;
    notifyListeners();
  }

  @override
  Future<MapResponse> getMapData({
    required MapBounds bounds,
    String? category,
  }) {
    mapDataCalls.add((bounds: bounds, category: category));
    final handler = onGetMapData;
    if (handler != null) return handler(bounds, category);
    return Future.value(mapResponse ?? const MapResponse(mapItems: []));
  }

  @override
  Future<MapResponse> getNearbyPins({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    nearbyCalls.add((latitude, longitude));
    if (nearbyFails) throw Exception('nearby failed');
    return nearbyResponse ?? const MapResponse(mapItems: []);
  }

  @override
  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
    int limit = 8,
  }) {
    lastMapSearchQuery = query;
    lastMapSearchCategory = category;
    lastMapSearchSessionToken = sessionToken;
    final handler = onMapSearch;
    if (handler != null) {
      return handler(
        query: query,
        category: category,
        sessionToken: sessionToken,
      );
    }
    return Future.value(
      MapPlaceSearchResponse(
        query: query,
        searchMode: 'google',
        total: 0,
        results: const [],
      ),
    );
  }

  @override
  Future<MapItem> pinMapPlace(
    String googlePlaceId, {
    String? sessionToken,
  }) async {
    return pinnedMapItem ?? _manualMapItem;
  }

  @override
  Future<void> removeMapItem(String mapItemId) async {
    removedMapItemIds.add(mapItemId);
  }

  @override
  Future<SearchResponse> search(
    String query, {
    String? category,
    String? subcategory,
  }) {
    return onSearch(query: query, category: category, subcategory: subcategory);
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}
}

const _travelReel = Reel(
  id: 'travel-1',
  userId: 'user-123',
  url: 'https://example.com/travel',
  title: 'Coffee crawl',
  summary: 'A guide to coffee shops',
  caption: '',
  transcript: '',
  category: 'Travel',
  subCategory: 'Coffee Shops',
  keyFacts: [],
  locations: [Location(name: 'Brew Lab', latitude: 12.97, longitude: 77.59)],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-20T00:00:00Z',
);

const _travelMapItem = MapItem(
  reelId: 'travel-1',
  title: 'Coffee crawl',
  summary: 'A guide to coffee shops',
  category: 'Travel',
  subCategory: 'Coffee Shops',
  categoryLabel: 'Travel',
  locations: [],
  markerId: _locationId,
  latitude: 12.97,
  longitude: 77.59,
  mapItemId: _locationId,
  locationName: 'Brew Lab',
  locationDisplayLabel: 'Brew Lab',
  googleMapsUrl: 'https://maps.example/brew-lab',
  canRemove: false,
);

const _manualMapItem = MapItem(
  reelId: '',
  title: 'Manual Cafe',
  summary: '12 Market Street',
  category: 'Food',
  subCategory: 'Cafes',
  categoryLabel: 'Food',
  subCategoryLabel: 'Cafes',
  locations: [],
  markerId: 'manual:pin-1',
  latitude: 12.91,
  longitude: 77.61,
  mapItemId: 'manual:pin-1',
  sourceType: 'manual',
  displayTitle: 'Manual Cafe',
  shortDetail: '12 Market Street',
  locationName: 'Manual Cafe',
  locationDisplayLabel: '12 Market Street',
  googleMapsUrl: 'https://maps.example/manual-cafe',
  googlePlaceId: 'place-1',
  canHide: false,
);

const _lockedMapItem = MapItem(
  reelId: 'travel-1',
  title: 'Coffee crawl',
  summary: '',
  category: 'Travel',
  subCategory: '',
  categoryLabel: 'Travel',
  locations: [],
  markerId: 'locked-1',
  latitude: 12.97,
  longitude: 77.59,
  locationName: 'Brew Lab',
  locationDisplayLabel: 'Brew Lab',
  canHide: false,
  canRemove: false,
);

const _locationId = '66666666-6666-4666-8666-666666666666';

const _goa = MapBounds(south: 15, west: 73, north: 16, east: 74);

const _mumbai = MapBounds(south: 18.8, west: 72.7, north: 19.3, east: 73.1);

const _foodReel = Reel(
  id: 'food-1',
  userId: 'user-123',
  url: 'https://example.com/food',
  title: 'Food trail',
  summary: 'Street food highlights',
  caption: '',
  transcript: '',
  category: 'Food',
  subCategory: 'Street Food',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-19T00:00:00Z',
);
