import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/utils/error_message.dart';

/// Holds the platform → category → subcategory facet tree for the home filter.
///
/// The whole tree arrives in a single response, so narrowing by platform is a
/// lookup here rather than another request.
class ReelFiltersViewModel extends ChangeNotifier {
  ReelFiltersViewModel(this._repository);

  final ReelRepository _repository;

  ReelFiltersResponse? _response;
  bool _isLoading = false;
  String? _error;

  ReelFiltersResponse? get response => _response;

  List<ReelPlatformGroup> get platforms =>
      List.unmodifiable(_response?.platforms ?? const <ReelPlatformGroup>[]);

  /// Categories across every platform. Used wherever the platform dimension
  /// does not apply, such as the map's own category row.
  List<ReelCategoryGroup> get categoryGroups =>
      List.unmodifiable(_response?.categories ?? const <ReelCategoryGroup>[]);

  List<String> get categories => categoryGroups
      .map((group) => group.category)
      .toList(growable: false);

  int get totalCount => _response?.totalCount ?? 0;
  int get selectedPreviewCount => _response?.selectedPreviewCount ?? 0;
  String? get topPlatform => _response?.topPlatform;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPlatforms => platforms.isNotEmpty;
  bool get hasGroups => categoryGroups.isNotEmpty;

  ReelPlatformGroup? platformNamed(String? platform) =>
      _response?.platformNamed(platform);

  /// The categories to offer for [platform], falling back to the cross-platform
  /// aggregate when nothing is selected.
  List<ReelCategoryGroup> categoriesFor(String? platform) {
    if (platform == null) return categoryGroups;
    return platformNamed(platform)?.categories ?? const <ReelCategoryGroup>[];
  }

  /// Resolves how many reels the given combination would return, straight from
  /// the tree — no request needed to keep the apply button's count honest.
  int previewCountFor({
    String? platform,
    String? category,
    String? subcategory,
  }) {
    if (platform == null && category == null) return totalCount;

    final scoped = platform == null ? categoryGroups : categoriesFor(platform);
    if (category == null) {
      // A platform the tree has never heard of holds nothing. Falling back to
      // the total here would promise reels the filter cannot deliver.
      return platformNamed(platform)?.count ?? 0;
    }

    ReelCategoryGroup? group;
    for (final item in scoped) {
      if (item.category == category) {
        group = item;
        break;
      }
    }
    if (group == null) return 0;

    if (subcategory != null) {
      return group.subcategoryNamed(subcategory)?.count ?? 0;
    }
    return group.count;
  }

  void reset() {
    _response = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Restores the last saved facet tree so the header renders immediately.
  /// No-ops once live data has arrived.
  Future<void> hydrateFromCache() async {
    if (_response != null) return;

    final payload = await ContentCache.instance.read(
      ContentCacheKeys.reelFilters,
    );
    if (payload == null) return;
    if (_response != null) return;

    try {
      final response = ReelFiltersResponse.fromJson(payload);
      if (response.platforms.isEmpty && response.categories.isEmpty) return;

      _response = response;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached reel filters could not be restored: $e');
      unawaited(ContentCache.instance.invalidate(ContentCacheKeys.reelFilters));
    }
  }

  Future<void> loadFilters({
    bool forceRefresh = false,
    String? platform,
    String? category,
    String? subcategory,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _response = await _repository.getFilters(
        platform: platform,
        category: category,
        subcategory: subcategory,
      );
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load filters right now.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
