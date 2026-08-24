import 'package:flutter/foundation.dart';

import 'package:reelpin/utils/app_logger.dart';

import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/discover/search_result.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/search/query_understanding_service.dart';
import 'package:reelpin/utils/error_message.dart';

/// ViewModel for the RAG Search screen.
class SearchViewModel extends ChangeNotifier {
  static const minimumQueryLength = 3;

  final ReelRepository _repository;

  SearchViewModel(this._repository, {QueryUnderstandingService? queryUnderstanding})
    : _queryUnderstanding = queryUnderstanding;

  /// Absent in tests and wherever parsing is not wanted, in which case
  /// [searchWithAi] degrades to [search].
  final QueryUnderstandingService? _queryUnderstanding;

  List<SearchResult> _results = [];
  bool _isSearching = false;
  String? _error;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String _lastQuery = '';
  int _searchRequestId = 0;
  SearchMode? _backendSearchMode;
  int _total = 0;

  List<SearchResult> get results => List.unmodifiable(_results);
  int get total => _total;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubcategory => _selectedSubcategory;
  String get lastQuery => _lastQuery;
  bool get hasResults => _results.isNotEmpty;
  SearchMode? get backendSearchMode => _backendSearchMode;
  bool get isQueryTooShort =>
      _lastQuery.isNotEmpty && _lastQuery.length < minimumQueryLength;

  /// Execute a RAG search query.
  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      clear();
      return;
    }

    _lastQuery = normalizedQuery;
    if (normalizedQuery.length < minimumQueryLength) {
      _repository.cancelActiveSearch();
      _searchRequestId += 1;
      _results = [];
      _total = 0;
      _error = null;
      _isSearching = false;
      notifyListeners();
      return;
    }

    final requestId = ++_searchRequestId;
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.search(
        normalizedQuery,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
      );
      if (requestId != _searchRequestId) return;

      _results = response.results;
      _total = response.total;
      _backendSearchMode = response.searchMode;
      _error = null;
      if (kDebugMode) {
        AppLogger.debug(
          'SEARCH MODE: ${response.searchMode.name} '
          'query="${response.query}" total=${response.total}',
        );
      }
    } on SearchCancelledException {
      return;
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Search is not available right now.',
      );
    } finally {
      if (requestId == _searchRequestId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Submit-time search: Gemini fixes spelling and moves concepts out of the
  /// query string into the category filters before the request goes out.
  ///
  /// The backend ANDs every token it receives, so promoting a word to a facet
  /// widens the result set where leaving it in the string would narrow it.
  ///
  /// Any parsing failure degrades to [search]'s exact behaviour, so this can
  /// never return less than typing the same text would.
  Future<void> searchWithAi(
    String query, {
    List<ReelCategoryGroup> facets = const [],
  }) async {
    final normalizedQuery = query.trim();
    final parser = _queryUnderstanding;
    if (parser == null || normalizedQuery.length < minimumQueryLength) {
      return search(normalizedQuery);
    }

    _lastQuery = normalizedQuery;
    _isSearching = true;
    _error = null;
    notifyListeners();

    final parsed =
        await parser.parse(normalizedQuery, facets: facets) ??
        ParsedQuery.fallback(normalizedQuery);

    if (kDebugMode) {
      AppLogger.debug(
        'AI PARSE: "$normalizedQuery" -> query="${parsed.semanticQuery}" '
        'category=${parsed.category} subcategory=${parsed.subcategory} '
        'limit=${parsed.limit}',
      );
    }

    final requestId = ++_searchRequestId;
    try {
      var response = await _repository.search(
        parsed.semanticQuery,
        category: parsed.category ?? _selectedCategory,
        subcategory: parsed.subcategory ?? _selectedSubcategory,
        limit: parsed.limit,
      );
      if (requestId != _searchRequestId) return;

      // Parsing can over-constrain: the backend ANDs every token in the query
      // string *and* applies the facets, so a concept the model both kept in
      // the text and promoted to a category gets filtered twice. When that
      // wipes out the results, fall back to what plain search would have done
      // rather than showing an empty state the user did not deserve.
      if (response.results.isEmpty && parsed.semanticQuery != normalizedQuery) {
        if (kDebugMode) {
          AppLogger.debug('AI RETRY: parsed search empty, retrying raw query');
        }
        response = await _repository.search(
          normalizedQuery,
          category: _selectedCategory,
          subcategory: _selectedSubcategory,
        );
        if (requestId != _searchRequestId) return;
      }

      _results = response.results;
      _total = response.total;
      _backendSearchMode = response.searchMode;
      _error = null;
      if (kDebugMode) {
        AppLogger.debug(
          'SEARCH MODE: ${response.searchMode.name} '
          'query="${response.query}" total=${response.total}',
        );
      }
    } on SearchCancelledException {
      return;
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Search is not available right now.',
      );
    } finally {
      if (requestId == _searchRequestId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  void updateFilters({String? category, String? subcategory}) {
    _selectedCategory = category;
    _selectedSubcategory = subcategory;
    notifyListeners();

    if (_lastQuery.isNotEmpty) {
      search(_lastQuery);
    }
  }

  void clearFilters() {
    _selectedCategory = null;
    _selectedSubcategory = null;
    notifyListeners();

    if (_lastQuery.isNotEmpty) {
      search(_lastQuery);
    }
  }

  /// Clear search results.
  void clear() {
    _repository.cancelActiveSearch();
    _searchRequestId += 1;
    _results = [];
    _total = 0;
    _lastQuery = '';
    _backendSearchMode = null;
    _error = null;
    _isSearching = false;
    notifyListeners();
  }

  void removeReel(String reelId) {
    final next = _results
        .where((result) => result.reel.id != reelId)
        .toList(growable: false);
    if (next.length == _results.length) return;

    _results = next;
    notifyListeners();
  }
}
