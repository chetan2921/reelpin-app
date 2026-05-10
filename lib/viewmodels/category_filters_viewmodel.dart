import 'package:flutter/foundation.dart';

import '../models/reel_category_filters.dart';
import '../repositories/reel_repository.dart';

class CategoryFiltersViewModel extends ChangeNotifier {
  CategoryFiltersViewModel(this._repository);

  final ReelRepository _repository;

  List<ReelCategoryGroup> _groups = const [];
  ReelCategoryCatalog _catalog = const ReelCategoryCatalog([]);
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchedAt;

  List<ReelCategoryGroup> get groups => List.unmodifiable(_groups);
  List<String> get categories => _catalog.categories;
  ReelCategoryCatalog get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasGroups => _groups.isNotEmpty;

  List<String> subcategoriesFor(String? category) {
    return _catalog.subcategoriesFor(category);
  }

  void reset() {
    _groups = const [];
    _catalog = const ReelCategoryCatalog([]);
    _isLoading = false;
    _error = null;
    _lastFetchedAt = null;
    notifyListeners();
  }

  Future<void> loadCategoryFilters({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cacheIsFresh =
        _lastFetchedAt != null &&
        now.difference(_lastFetchedAt!).inSeconds < 30 &&
        !forceRefresh;

    if (cacheIsFresh) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getCategoryFilters();
      _groups = response.categories;
      _catalog = ReelCategoryCatalog(_groups);
      _lastFetchedAt = now;
    } catch (e) {
      _error = e.toString();
      if (_groups.isEmpty) {
        _catalog = const ReelCategoryCatalog([]);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
