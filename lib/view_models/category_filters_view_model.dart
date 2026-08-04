import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/data_models/reels/reel_category_filters.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/utils/error_message.dart';

class CategoryFiltersViewModel extends ChangeNotifier {
  CategoryFiltersViewModel(this._repository);

  final ReelRepository _repository;

  List<ReelCategoryGroup> _groups = const [];
  ReelCategoryFiltersResponse? _response;
  bool _isLoading = false;
  String? _error;

  List<ReelCategoryGroup> get groups => List.unmodifiable(_groups);
  List<String> get categories =>
      _groups.map((group) => group.category).toList(growable: false);
  ReelCategoryFiltersResponse? get response => _response;
  int get totalCount => _response?.totalCount ?? 0;
  int get selectedPreviewCount => _response?.selectedPreviewCount ?? 0;
  String? get topCategory => _response?.topCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasGroups => _groups.isNotEmpty;

  void reset() {
    _groups = const [];
    _response = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Restores the last saved filter chips so the header renders immediately.
  /// No-ops once live data has arrived.
  Future<void> hydrateFromCache() async {
    if (_groups.isNotEmpty) return;

    final payload = await ContentCache.instance.read(
      ContentCacheKeys.categoryFilters,
    );
    if (payload == null) return;
    if (_groups.isNotEmpty) return;

    try {
      final response = ReelCategoryFiltersResponse.fromJson(payload);
      if (response.categories.isEmpty) return;

      _response = response;
      _groups = response.categories;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached category filters could not be restored: $e');
      unawaited(
        ContentCache.instance.invalidate(ContentCacheKeys.categoryFilters),
      );
    }
  }

  Future<void> loadCategoryFilters({
    bool forceRefresh = false,
    String? category,
    String? subcategory,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getCategoryFilters(
        category: category,
        subcategory: subcategory,
      );
      _response = response;
      _groups = response.categories;
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load category filters right now.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
