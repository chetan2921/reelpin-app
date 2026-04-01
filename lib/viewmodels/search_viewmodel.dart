import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
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
  String _lastQuery = '';

  List<SearchResult> get results => List.unmodifiable(_results);
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String get lastQuery => _lastQuery;
  bool get hasResults => _results.isNotEmpty;

  /// Execute a RAG search query.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    _lastQuery = query;
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _repository.search(query, category: null);
      if (_selectedCategory == null) {
        _results = fetched;
      } else {
        final selected = _selectedCategory!;
        _results = fetched
            .where(
              (r) =>
                  _matchesFilter(r.reel.category, r.reel.subCategory, selected),
            )
            .toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Filter search by category.
  void filterByCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
    // Re-run last search with new filter
    if (_lastQuery.isNotEmpty) {
      search(_lastQuery);
    }
  }

  /// Clear search results.
  void clear() {
    _results.clear();
    _lastQuery = '';
    _error = null;
    notifyListeners();
  }

  bool _matchesFilter(String category, String subCategory, String selected) {
    final grouped = ApiConfig.categoryGroups[selected];
    if (grouped != null) {
      return _matchesCategoryOrSubCategory(category, subCategory, selected) ||
          grouped.any(
            (c) => _matchesCategoryOrSubCategory(category, subCategory, c),
          );
    }
    return _matchesCategoryOrSubCategory(category, subCategory, selected);
  }

  bool _matchesCategoryOrSubCategory(
    String category,
    String subCategory,
    String value,
  ) {
    final normalized = _normalize(value);
    return _normalize(category) == normalized ||
        _normalize(subCategory) == normalized;
  }

  String _normalize(String value) => value.trim().toLowerCase();
}
