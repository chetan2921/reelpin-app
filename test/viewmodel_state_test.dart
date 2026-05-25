import 'package:flutter_test/flutter_test.dart';
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
}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository({required this.onSearch})
    : cachedReels = const [],
      mapResponse = null,
      super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

  _FakeReelRepository.empty({this.cachedReels = const [], this.mapResponse})
    : onSearch = _emptySearch,
      super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

  final Future<SearchResponse> Function({
    required String query,
    String? category,
    String? subcategory,
  })
  onSearch;

  @override
  final List<Reel> cachedReels;

  final MapResponse? mapResponse;
  String? lastCategory;
  String? lastSubcategory;

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
  locationName: 'Brew Lab',
  locationDisplayLabel: 'Brew Lab',
  googleMapsUrl: 'https://maps.example/brew-lab',
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
