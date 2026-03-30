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
      _results = await _repository.search(query, category: _selectedCategory);
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
}
