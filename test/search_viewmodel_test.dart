import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/models/search_response.dart';
import 'package:reelpin/models/search_result.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/api_service.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:reelpin/viewmodels/search_viewmodel.dart';
import 'package:reelpin/models/user_entitlement.dart';
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
}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository({required this.onSearch})
    : super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

  final Future<SearchResponse> Function({
    required String query,
    String? category,
    String? subcategory,
  })
  onSearch;

  var searchCalls = 0;
  var cancelCalls = 0;

  @override
  Future<SearchResponse> search(
    String query, {
    String? category,
    String? subcategory,
  }) {
    searchCalls += 1;
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
