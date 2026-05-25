import 'package:flutter/foundation.dart';

import '../models/search_result.dart';
import '../models/user_entitlement.dart';
import '../repositories/reel_repository.dart';
import '../services/api_service.dart';

/// ViewModel for the RAG Search screen.
class SearchViewModel extends ChangeNotifier {
  static const minimumQueryLength = 3;

  final ReelRepository _repository;

  SearchViewModel(this._repository);

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
