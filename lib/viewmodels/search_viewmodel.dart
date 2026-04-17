import 'package:flutter/foundation.dart';

import '../models/search_result.dart';
import '../repositories/reel_repository.dart';

/// ViewModel for the RAG Search screen.
class SearchViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  SearchViewModel(this._repository);

  List<SearchResult> _results = [];
  bool _isSearching = false;
  String? _error;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String _lastQuery = '';
  int _searchRequestId = 0;

  List<SearchResult> get results => List.unmodifiable(_results);
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubcategory => _selectedSubcategory;
  String get lastQuery => _lastQuery;
  bool get hasResults => _results.isNotEmpty;

  /// Execute a RAG search query.
  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      clear();
      return;
    }

    final requestId = ++_searchRequestId;
    _lastQuery = normalizedQuery;
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _repository.search(
        normalizedQuery,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
      );
      if (requestId != _searchRequestId) return;

      _results = fetched;
      _error = null;
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _error = e.toString();
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
    _searchRequestId += 1;
    _results.clear();
    _lastQuery = '';
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
