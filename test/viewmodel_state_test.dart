import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/map_place_search_response.dart';
import 'package:reelpin/models/map_response.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/models/search_response.dart';
import 'package:reelpin/models/search_result.dart';
import 'package:reelpin/models/user_entitlement.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/api_service.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:reelpin/viewmodels/home_viewmodel.dart';
import 'package:reelpin/viewmodels/map_viewmodel.dart';
import 'package:reelpin/viewmodels/search_viewmodel.dart';
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
      mapResponse: const MapResponse(
        totalPinnedLocations: 1,
        visiblePinnedLocations: 1,
        mapItems: [_travelMapItem],
      ),
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
    expect(
      viewModel.placeSearchResults.single.mapItem?.markerId,
      'travel-1-brew-lab',
    );
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

  test('removeMapItem hides selected pin locally', () async {
    final repository = _FakeReelRepository.empty(
      mapResponse: const MapResponse(
        totalPinnedLocations: 2,
        visiblePinnedLocations: 2,
        mapItems: [_travelMapItem, _manualMapItem],
      ),
    );
    final viewModel = MapViewModel(repository);
    await viewModel.loadMapReels(forceRefresh: true);
    viewModel.selectMapItem(_manualMapItem);

    final success = await viewModel.removeMapItem(_manualMapItem);

    expect(success, isTrue);
    expect(repository.removedMapItemIds, ['manual:pin-1']);
    expect(viewModel.mapItems.map((item) => item.mapItemId), [
      'reel:travel-1:0',
    ]);
    expect(viewModel.selectedMapItem, isNull);
    expect(viewModel.totalPinnedLocations, 1);
    expect(viewModel.visiblePinnedLocations, 1);
  });
}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository({required this.onSearch})
    : cachedReels = const [],
      mapResponse = null,
      onMapSearch = null,
      pinnedMapItem = null,
      super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

  _FakeReelRepository.empty({
    this.cachedReels = const [],
    this.mapResponse,
    this.onMapSearch,
    this.pinnedMapItem,
  }) : onSearch = _emptySearch,
       super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

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
  final MapItem? pinnedMapItem;
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
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    lastCategory = category;
    lastSubcategory = subcategory;
    notifyListeners();
  }

  @override
  Future<MapResponse> getMapData({String? category}) async {
    return mapResponse ??
        const MapResponse(
          totalPinnedLocations: 0,
          visiblePinnedLocations: 0,
          mapItems: [],
        );
  }

  @override
  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
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
  locations: [
    Location(
      name: 'Brew Lab',
      latitude: 12.97,
      longitude: 77.59,
      isDirectMention: true,
    ),
  ],
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
  markerId: 'travel-1-brew-lab',
  latitude: 12.97,
  longitude: 77.59,
  mapItemId: 'reel:travel-1:0',
  locationName: 'Brew Lab',
  locationDisplayLabel: 'Brew Lab',
  googleMapsUrl: 'https://maps.example/brew-lab',
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
  sourceId: 'pin-1',
  displayTitle: 'Manual Cafe',
  shortDetail: '12 Market Street',
  locationName: 'Manual Cafe',
  locationDisplayLabel: '12 Market Street',
  googleMapsUrl: 'https://maps.example/manual-cafe',
  googlePlaceId: 'place-1',
);

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
