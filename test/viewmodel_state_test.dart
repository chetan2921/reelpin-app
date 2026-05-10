import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/models/search_result.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/api_service.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:reelpin/services/reel_store.dart';
import 'package:reelpin/viewmodels/home_viewmodel.dart';
import 'package:reelpin/viewmodels/map_viewmodel.dart';
import 'package:reelpin/viewmodels/search_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('home filters only expose matching reels', () {
    final viewModel = HomeViewModel(_FakeReelRepository.empty());
    viewModel.upsertProcessedReel(_travelReel);
    viewModel.upsertProcessedReel(_foodReel);

    viewModel.applyFilters(category: 'Travel', subcategory: 'Coffee Shops');

    expect(viewModel.reels.map((reel) => reel.id), ['travel-1']);
  });

  test('map removal clears selected reel state', () {
    final viewModel = MapViewModel(_FakeReelRepository.empty());
    viewModel.upsertProcessedReel(_travelReel);
    viewModel.selectReel(
      _travelReel,
      location: _travelReel.mappableLocations.first,
    );

    viewModel.removeReel(_travelReel.id);

    expect(viewModel.reelsWithLocations, isEmpty);
    expect(viewModel.selectedReel, isNull);
    expect(viewModel.selectedLocation, isNull);
  });

  test('search removal drops deleted reels from results', () async {
    final repository = _FakeReelRepository(
      onSearch: ({
        required String query,
        String? category,
        String? subcategory,
      }) async => [
        SearchResult(reel: _travelReel, relevanceScore: 0.9),
        SearchResult(reel: _foodReel, relevanceScore: 0.8),
      ],
    );
    final viewModel = SearchViewModel(repository);

    await viewModel.search('coffee');
    viewModel.removeReel(_travelReel.id);

    expect(viewModel.results.map((result) => result.reel.id), ['food-1']);
  });
}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository({required this.onSearch})
    : super(
        ApiService(baseUrl: 'https://example.com'),
        ReelStore(),
        _FakeAuthService(),
      );

  _FakeReelRepository.empty()
    : onSearch = _emptySearch,
      super(
        ApiService(baseUrl: 'https://example.com'),
        ReelStore(),
        _FakeAuthService(),
      );

  final Future<List<SearchResult>> Function({
    required String query,
    String? category,
    String? subcategory,
  })
  onSearch;

  static Future<List<SearchResult>> _emptySearch({
    required String query,
    String? category,
    String? subcategory,
  }) async => const [];

  @override
  Future<List<SearchResult>> search(
    String query, {
    String? category,
    String? subcategory,
  }) {
    return onSearch(
      query: query,
      category: category,
      subcategory: subcategory,
    );
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
