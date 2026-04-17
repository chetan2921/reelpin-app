import 'package:flutter/foundation.dart';

import '../models/reel_category_filters.dart';
import '../repositories/reel_repository.dart';

class CategoryFiltersViewModel extends ChangeNotifier {
  CategoryFiltersViewModel(this._repository) {
    ReelCategoryCatalog.replaceAll(const []);
  }

  final ReelRepository _repository;

  List<ReelCategoryGroup> _groups = const [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchedAt;

  List<ReelCategoryGroup> get groups => List.unmodifiable(_groups);
  List<String> get categories =>
      _groups.map((group) => group.category).toList(growable: false);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasGroups => _groups.isNotEmpty;

  List<String> subcategoriesFor(String? category) {
    return ReelCategoryCatalog.subcategoriesFor(category);
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
      ReelCategoryCatalog.replaceAll(_groups);
      _lastFetchedAt = now;
    } catch (e) {
      _error = e.toString();
      if (_groups.isEmpty) {
        ReelCategoryCatalog.replaceAll(const []);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
