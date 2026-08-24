import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/discover/search_response.dart';
import 'package:reelpin/data_models/discover/search_result.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/search/query_understanding_service.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/search_view_model.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('short queries stay local and do not hit repository search', () async {
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async => _searchResponse(query, [_resultFor(query)]),
    );
    final viewModel = SearchViewModel(repository);

    await viewModel.search('ab');

    expect(repository.searchCalls, 0);
    expect(repository.cancelCalls, 1);
    expect(viewModel.isQueryTooShort, isTrue);
    expect(viewModel.results, isEmpty);
    expect(viewModel.isSearching, isFalse);
  });

  test('latest search result wins when earlier requests finish late', () async {
    final first = Completer<SearchResponse>();
    final second = Completer<SearchResponse>();
    var callCount = 0;

    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) {
            callCount += 1;
            return callCount == 1 ? first.future : second.future;
          },
    );
    final viewModel = SearchViewModel(repository);

    unawaited(viewModel.search('travel'));
    await Future<void>.delayed(Duration.zero);
    unawaited(viewModel.search('coffee'));
    await Future<void>.delayed(Duration.zero);

    second.complete(_searchResponse('coffee', [_resultFor('coffee')]));
    await Future<void>.delayed(Duration.zero);
    first.complete(_searchResponse('travel', [_resultFor('travel')]));
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.results.single.reel.title, 'coffee');
    expect(viewModel.lastQuery, 'coffee');
    expect(viewModel.error, isNull);
  });

  test('clear resets fixed-length search results', () async {
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async => _searchResponse(query, [_resultFor(query)]),
    );
    final viewModel = SearchViewModel(repository);

    await viewModel.search('gym');
    viewModel.clear();

    expect(viewModel.results, isEmpty);
    expect(viewModel.lastQuery, isEmpty);
    expect(viewModel.isSearching, isFalse);
    expect(viewModel.error, isNull);
  });
  test('searchWithAi sends parsed params to the repository', () async {
    String? seenQuery;
    String? seenCategory;
    String? seenSubcategory;
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async {
            seenQuery = query;
            seenCategory = category;
            seenSubcategory = subcategory;
            return _searchResponse(query, [_resultFor(query)]);
          },
    );
    final viewModel = SearchViewModel(
      repository,
      queryUnderstanding: _FakeQueryUnderstanding(
        const ParsedQuery(
          semanticQuery: 'Bangalore',
          rawQuery: 'travel in banglore',
          category: 'travel',
          subcategory: 'road trips',
          limit: 5,
        ),
      ),
    );

    await viewModel.searchWithAi('travel in banglore');

    expect(seenQuery, 'Bangalore');
    expect(seenCategory, 'travel');
    expect(seenSubcategory, 'road trips');
    expect(repository.lastLimit, 5);
    expect(viewModel.results, hasLength(1));
  });

  test('searchWithAi falls back to the raw query when parsing fails', () async {
    String? seenQuery;
    String? seenCategory;
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async {
            seenQuery = query;
            seenCategory = category;
            return _searchResponse(query, [_resultFor(query)]);
          },
    );
    final viewModel = SearchViewModel(
      repository,
      queryUnderstanding: _FakeQueryUnderstanding(null),
    );

    await viewModel.searchWithAi('travel in Karnataka');

    expect(seenQuery, 'travel in Karnataka');
    expect(seenCategory, isNull);
    expect(viewModel.results, hasLength(1));
    expect(viewModel.error, isNull);
    expect(viewModel.isSearching, isFalse);
  });

  test('searchWithAi passes the facet tree to the parser', () async {
    const facets = <ReelCategoryGroup>[
      ReelCategoryGroup(
        category: 'food',
        label: 'Food',
        count: 1,
        subcategories: [],
      ),
    ];
    final parser = _FakeQueryUnderstanding(null);
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async =>
              _searchResponse(query, const []),
    );
    final viewModel = SearchViewModel(repository, queryUnderstanding: parser);

    await viewModel.searchWithAi('cafes', facets: facets);

    expect(parser.lastFacets, facets);
  });

  test('searchWithAi keeps the manual filters when the parser omits them', () async {
    String? seenCategory;
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async {
            seenCategory = category;
            return _searchResponse(query, const []);
          },
    );
    final viewModel = SearchViewModel(
      repository,
      queryUnderstanding: _FakeQueryUnderstanding(
        const ParsedQuery(semanticQuery: 'cafes', rawQuery: 'cafes'),
      ),
    );
    viewModel.updateFilters(category: 'food');

    await viewModel.searchWithAi('cafes');

    expect(seenCategory, 'food');
  });

  test('searchWithAi skips parsing for queries below the minimum', () async {
    final parser = _FakeQueryUnderstanding(null);
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async =>
              _searchResponse(query, const []),
    );
    final viewModel = SearchViewModel(repository, queryUnderstanding: parser);

    await viewModel.searchWithAi('ab');

    expect(parser.calls, 0);
    expect(repository.searchCalls, 0);
    expect(viewModel.isQueryTooShort, isTrue);
  });

  test('keyword search never invokes the parser', () async {
    final parser = _FakeQueryUnderstanding(null);
    final repository = _FakeReelRepository(
      onSearch:
          ({required String query, String? category, String? subcategory}) async =>
              _searchResponse(query, [_resultFor(query)]),
    );
    final viewModel = SearchViewModel(repository, queryUnderstanding: parser);

    await viewModel.search('travel');

    expect(parser.calls, 0);
    expect(repository.searchCalls, 1);
  });

  test('searchWithAi without a parser behaves exactly like keyword search', () async {
    String? seenQuery;
    final repository = _FakeReelRepository(
      onSearch:
          ({
            required String query,
            String? category,
            String? subcategory,
          }) async {
            seenQuery = query;
            return _searchResponse(query, [_resultFor(query)]);
          },
    );
    final viewModel = SearchViewModel(repository);

    await viewModel.searchWithAi('travel in Karnataka');

    expect(seenQuery, 'travel in Karnataka');
    expect(viewModel.results, hasLength(1));
  });

}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository({required this.onSearch})
    : super(ApiClient(baseUrl: 'https://example.com'), _FakeAuthService());

  final Future<SearchResponse> Function({
    required String query,
    String? category,
    String? subcategory,
  })
  onSearch;

  var searchCalls = 0;
  var cancelCalls = 0;
  int? lastLimit;

  @override
  Future<SearchResponse> search(
    String query, {
    String? category,
    String? subcategory,
    int? limit,
  }) {
    searchCalls += 1;
    lastLimit = limit;
    return onSearch(query: query, category: category, subcategory: subcategory);
  }

  @override
  void cancelActiveSearch() {
    cancelCalls += 1;
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

SearchResult _resultFor(String title) {
  return SearchResult(
    reel: Reel(
      id: title,
      userId: 'user-123',
      url: 'https://example.com/$title',
      title: title,
      summary: 'summary',
      caption: '',
      transcript: '',
      category: 'Travel',
      subCategory: 'Coffee Shops',
      keyFacts: const [],
      locations: const [],
      peopleMentioned: const [],
      actionableItems: const [],
      createdAt: '2026-04-20T00:00:00Z',
    ),
    relevanceScore: 0.9,
  );
}

SearchResponse _searchResponse(String query, List<SearchResult> results) {
  return SearchResponse(
    query: query,
    results: results,
    total: results.length,
    searchMode: SearchMode.rag,
  );
}


class _FakeQueryUnderstanding implements QueryUnderstandingService {
  _FakeQueryUnderstanding(this._result);

  final ParsedQuery? _result;
  int calls = 0;
  List<ReelCategoryGroup>? lastFacets;

  @override
  Future<ParsedQuery?> parse(
    String rawQuery, {
    required List<ReelCategoryGroup> facets,
  }) async {
    calls += 1;
    lastFacets = facets;
    return _result;
  }
}
