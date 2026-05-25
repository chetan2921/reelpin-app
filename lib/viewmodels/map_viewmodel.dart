import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/map_response.dart';
import '../models/reel.dart';
import '../repositories/reel_repository.dart';
import '../services/api_service.dart';

class MapViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  MapViewModel(this._repository);

  List<MapItem> _mapItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedCategory;
  MapItem? _selectedMapItem;
  int _totalPinnedLocations = 0;
  int _visiblePinnedLocations = 0;

  List<MapItem> get mapItems => List.unmodifiable(_mapItems);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => false;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  MapItem? get selectedMapItem => _selectedMapItem;
  int get totalPinnedLocations => _totalPinnedLocations;
  int get visiblePinnedLocations => _visiblePinnedLocations;

  @Deprecated('Use mapItems instead.')
  List<Reel> get reelsWithLocations =>
      _mapItems.map((item) => item.toReel()).toList(growable: false);

  @Deprecated('Use selectedMapItem instead.')
  Reel? get selectedReel => _selectedMapItem?.toReel();

  @Deprecated('Map selection now comes from backend map_items.')
  Location? get selectedLocation => null;

  Future<void> loadMapReels({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getMapData(
        category: _selectedCategory,
      );
      _mapItems = response.mapItems;
      _totalPinnedLocations = response.totalPinnedLocations;
      _visiblePinnedLocations = response.visiblePinnedLocations;
      _selectedCategory = response.selectedCategory ?? _selectedCategory;
      if (_selectedMapItem != null &&
          _mapItems.every(
            (item) => item.markerId != _selectedMapItem!.markerId,
          )) {
        _selectedMapItem = null;
      }
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load map data right now.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreReels() async {}

  void filterByCategory(String? category) {
    _selectedCategory = _selectedCategory == category ? null : category;
    _selectedMapItem = null;
    unawaited(loadMapReels(forceRefresh: true));
    notifyListeners();
  }

  void selectMapItem(MapItem? item) {
    _selectedMapItem = item;
    notifyListeners();
  }

  void selectReel(Reel? reel, {Location? location}) {
    if (reel == null) {
      selectMapItem(null);
    }
  }

  void reset() {
    _mapItems = const [];
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    _selectedCategory = null;
    _selectedMapItem = null;
    _totalPinnedLocations = 0;
    _visiblePinnedLocations = 0;
    notifyListeners();
  }

  void upsertProcessedReel(Reel reel) {
    unawaited(loadMapReels(forceRefresh: true));
  }

  void removeReel(String reelId) {
    final hadSelection = _selectedMapItem?.reelId == reelId;
    _mapItems = _mapItems
        .where((item) => item.reelId != reelId)
        .toList(growable: false);
    if (hadSelection) {
      _selectedMapItem = null;
    }
    notifyListeners();
  }
}
