import 'package:flutter/foundation.dart';

import '../models/discover_response.dart';
import '../models/reel.dart';
import '../models/reel_page.dart';
import '../repositories/reel_repository.dart';
import '../services/api_service.dart';

class DiscoverViewModel extends ChangeNotifier {
  DiscoverViewModel(this._repository);

  final ReelRepository _repository;

  DiscoverResponse? _discover;
  ReelPage? _categoryReelsPage;
  bool _isLoadingDiscover = false;
  bool _isLoadingCategoryReels = false;
  String? _discoverError;
  String? _categoryReelsError;
  String? _selectedSavedDate;
  String? _selectedSavedDateLabel;
  String? _selectedCategory;
  String? _selectedCategoryLabel;
  int? _selectedCategoryExpectedCount;
  int _discoverRequestId = 0;
  int _categoryRequestId = 0;

  DiscoverResponse? get discover => _discover;
  ReelPage? get categoryReelsPage => _categoryReelsPage;
  bool get isLoadingDiscover => _isLoadingDiscover;
  bool get isLoadingCategoryReels => _isLoadingCategoryReels;
  String? get discoverError => _discoverError;
  String? get categoryReelsError => _categoryReelsError;
  String? get selectedSavedDate => _selectedSavedDate;
  String? get selectedSavedDateLabel => _selectedSavedDateLabel;
  String? get selectedCategory => _selectedCategory;
  String? get selectedCategoryLabel => _selectedCategoryLabel;
  int? get selectedCategoryExpectedCount => _selectedCategoryExpectedCount;

  Future<void> loadDiscover({bool forceRefresh = false}) async {
    final requestId = ++_discoverRequestId;
    _isLoadingDiscover = true;
    _discoverError = null;
    notifyListeners();

    try {
      final response = await _repository.getDiscover(
        savedDate: _selectedSavedDate,
      );
      if (requestId != _discoverRequestId) return;

      _discover = response;
      _selectedSavedDate = response.selectedDate ?? _selectedSavedDate;
      _selectedSavedDateLabel = _labelForSavedDate(
        response,
        _selectedSavedDate,
      );
    } catch (e) {
      if (requestId != _discoverRequestId) return;

      _discoverError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load discover data right now.',
      );
    } finally {
      if (requestId == _discoverRequestId) {
        _isLoadingDiscover = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectSavedDate(SavedDateOption option) async {
    _selectedSavedDate = option.value;
    _selectedSavedDateLabel = option.label;
    _clearCategorySelectionInState();
    notifyListeners();
    await loadDiscover(forceRefresh: true);
  }

  Future<void> clearDateFilter() async {
    _selectedSavedDate = null;
    _selectedSavedDateLabel = null;
    _clearCategorySelectionInState();
    notifyListeners();
    await loadDiscover(forceRefresh: true);
  }

  Future<void> openCategory(DiscoverCategory category) async {
    final requestId = ++_categoryRequestId;
    _selectedSavedDate = null;
    _selectedSavedDateLabel = null;
    _selectedCategory = category.category;
    _selectedCategoryLabel = category.label;
    _selectedCategoryExpectedCount = category.count;
    _categoryReelsPage = null;
    _categoryReelsError = null;
    _isLoadingCategoryReels = true;
    notifyListeners();

    try {
      final page = await _repository.getReelsPage(
        category: category.category,
        limit: category.count,
      );
      if (requestId != _categoryRequestId ||
          _selectedCategory != category.category) {
        return;
      }

      _categoryReelsPage = page;
    } catch (e) {
      if (requestId != _categoryRequestId ||
          _selectedCategory != category.category) {
        return;
      }

      _categoryReelsError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load this category right now.',
      );
    } finally {
      if (requestId == _categoryRequestId &&
          _selectedCategory == category.category) {
        _isLoadingCategoryReels = false;
        notifyListeners();
      }
    }
  }

  void clearCategorySelection() {
    if (_selectedCategory == null &&
        _categoryReelsPage == null &&
        _categoryReelsError == null) {
      return;
    }

    _categoryRequestId += 1;
    _clearCategorySelectionInState();
    notifyListeners();
  }

  void clearTransientSelection() {
    var changed = false;
    if (_selectedSavedDate != null || _selectedSavedDateLabel != null) {
      _selectedSavedDate = null;
      _selectedSavedDateLabel = null;
      changed = true;
    }

    if (_selectedCategory != null ||
        _categoryReelsPage != null ||
        _categoryReelsError != null ||
        _isLoadingCategoryReels) {
      _categoryRequestId += 1;
      _clearCategorySelectionInState();
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  void removeReel(String reelId) {
    final discover = _discover;
    final categoryPage = _categoryReelsPage;
    var changed = false;

    if (discover != null) {
      final recentSaves = _withoutReel(discover.recentSaves, reelId);
      final reelsForSelectedDate = _withoutReel(
        discover.reelsForSelectedDate,
        reelId,
      );
      final didRemoveFromDiscover =
          recentSaves.length != discover.recentSaves.length ||
          reelsForSelectedDate.length != discover.reelsForSelectedDate.length;
      final categoryGrid = didRemoveFromDiscover
          ? discover.categoryGrid
                .map((item) {
                  final canReduceSelectedCategory =
                      item.category == _selectedCategory && item.count > 0;
                  if (!canReduceSelectedCategory) return item;

                  return DiscoverCategory(
                    category: item.category,
                    label: item.label,
                    count: item.count - 1,
                  );
                })
                .toList(growable: false)
          : discover.categoryGrid;

      if (didRemoveFromDiscover) {
        _discover = DiscoverResponse(
          recentSaves: recentSaves,
          recentSavesCount: discover.recentSavesCount > 0
              ? discover.recentSavesCount - 1
              : 0,
          savedDates: discover.savedDates,
          reelsForSelectedDate: reelsForSelectedDate,
          categoryGrid: categoryGrid,
          quickSearchPrompts: discover.quickSearchPrompts,
          pagination: discover.pagination,
          selectedDate: discover.selectedDate,
        );
        changed = true;
      }
    }

    if (categoryPage != null) {
      final categoryReels = _withoutReel(categoryPage.reels, reelId);
      if (categoryReels.length != categoryPage.reels.length) {
        _categoryReelsPage = ReelPage(
          reels: categoryReels,
          hasMore: categoryPage.hasMore,
          totalCount: categoryPage.totalCount > 0
              ? categoryPage.totalCount - 1
              : 0,
          limit: categoryPage.limit,
          offset: categoryPage.offset,
          nextCursor: categoryPage.nextCursor,
          nextOffset: categoryPage.nextOffset,
        );
        _selectedCategoryExpectedCount =
            _selectedCategoryExpectedCount != null &&
                _selectedCategoryExpectedCount! > 0
            ? _selectedCategoryExpectedCount! - 1
            : _selectedCategoryExpectedCount;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void reset() {
    _discoverRequestId += 1;
    _categoryRequestId += 1;
    _discover = null;
    _categoryReelsPage = null;
    _isLoadingDiscover = false;
    _isLoadingCategoryReels = false;
    _discoverError = null;
    _categoryReelsError = null;
    _selectedSavedDate = null;
    _selectedSavedDateLabel = null;
    _selectedCategory = null;
    _selectedCategoryLabel = null;
    _selectedCategoryExpectedCount = null;
    notifyListeners();
  }

  void _clearCategorySelectionInState() {
    _selectedCategory = null;
    _selectedCategoryLabel = null;
    _selectedCategoryExpectedCount = null;
    _categoryReelsPage = null;
    _categoryReelsError = null;
    _isLoadingCategoryReels = false;
  }

  String? _labelForSavedDate(DiscoverResponse response, String? savedDate) {
    if (savedDate == null || savedDate.isEmpty) {
      return null;
    }
    for (final option in response.savedDates) {
      if (option.value == savedDate) {
        return option.label;
      }
    }
    return savedDate;
  }

  List<Reel> _withoutReel(List<Reel> reels, String reelId) {
    return reels.where((reel) => reel.id != reelId).toList(growable: false);
  }
}
