import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/features/map/data/map_api.dart';
import 'package:reelpin/features/map/domain/map_place_search_response.dart';
import 'package:reelpin/features/map/domain/map_response.dart';
import 'package:reelpin/features/reels/domain/reel.dart';
import 'package:reelpin/core/network/error_message.dart';

class MapViewModel extends ChangeNotifier {
  final MapApi _mapApi;

  MapViewModel(this._mapApi);

  List<MapItem> _mapItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedCategory;
  MapItem? _selectedMapItem;
  int _totalPinnedLocations = 0;
  int _visiblePinnedLocations = 0;
  List<MapPlaceSearchResult> _placeSearchResults = [];
  bool _isSearchingPlaces = false;
  bool _isSavingMapPin = false;
  bool _isRemovingMapPin = false;
  String? _placeSearchError;
  String? _mapPinActionError;
  String _lastPlaceQuery = '';
  String _placeSearchSessionToken = '';
  int _placeSearchRequestId = 0;

  List<MapItem> get mapItems => List.unmodifiable(_mapItems);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => false;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  MapItem? get selectedMapItem => _selectedMapItem;
  int get totalPinnedLocations => _totalPinnedLocations;
  int get visiblePinnedLocations => _visiblePinnedLocations;
  List<MapPlaceSearchResult> get placeSearchResults =>
      List.unmodifiable(_placeSearchResults);
  bool get isSearchingPlaces => _isSearchingPlaces;
  bool get isSavingMapPin => _isSavingMapPin;
  bool get isRemovingMapPin => _isRemovingMapPin;
  String? get placeSearchError => _placeSearchError;
  String? get mapPinActionError => _mapPinActionError;
  String get lastPlaceQuery => _lastPlaceQuery;

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
      final response = await _mapApi.getMapData(category: _selectedCategory);
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
    clearPlaceSearch();
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
    _placeSearchResults = const [];
    _isSearchingPlaces = false;
    _isSavingMapPin = false;
    _isRemovingMapPin = false;
    _placeSearchError = null;
    _mapPinActionError = null;
    _lastPlaceQuery = '';
    _placeSearchSessionToken = '';
    _placeSearchRequestId += 1;
    notifyListeners();
  }

  Future<void> searchMapPlaces(String query) async {
    final normalizedQuery = query.trim();
    _lastPlaceQuery = normalizedQuery;

    if (normalizedQuery.length < 2) {
      _placeSearchRequestId += 1;
      _placeSearchResults = const [];
      _placeSearchError = null;
      _isSearchingPlaces = false;
      notifyListeners();
      return;
    }

    if (_placeSearchSessionToken.isEmpty) {
      _placeSearchSessionToken = DateTime.now().microsecondsSinceEpoch
          .toString();
    }

    final requestId = ++_placeSearchRequestId;
    _isSearchingPlaces = true;
    _placeSearchError = null;
    notifyListeners();

    try {
      final response = await _mapApi.searchMapPlaces(
        normalizedQuery,
        category: _selectedCategory,
        sessionToken: _placeSearchSessionToken,
      );
      if (requestId != _placeSearchRequestId) return;

      _placeSearchResults = response.results;
      _placeSearchError = null;
    } catch (e) {
      if (requestId != _placeSearchRequestId) return;

      _placeSearchError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not search map places right now.',
      );
    } finally {
      if (requestId == _placeSearchRequestId) {
        _isSearchingPlaces = false;
        notifyListeners();
      }
    }
  }

  Future<MapItem?> pinPlace(MapPlaceSearchResult result) async {
    final googlePlaceId = result.googlePlaceId?.trim();
    if (googlePlaceId == null || googlePlaceId.isEmpty) return null;

    _isSavingMapPin = true;
    _mapPinActionError = null;
    notifyListeners();

    try {
      final item = await _mapApi.pinMapPlace(
        googlePlaceId,
        sessionToken: _placeSearchSessionToken,
      );
      _upsertMapItem(item);
      _selectedMapItem = item;
      _totalPinnedLocations = _mapItems.length;
      _visiblePinnedLocations = _mapItems.length;
      _placeSearchSessionToken = '';
      _mapPinActionError = null;
      return item;
    } catch (e) {
      _mapPinActionError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not save this map pin right now.',
      );
      return null;
    } finally {
      _isSavingMapPin = false;
      notifyListeners();
    }
  }

  Future<bool> removeMapItem(MapItem item) async {
    final mapItemId = item.effectiveMapItemId.trim();
    if (mapItemId.isEmpty) return false;

    _isRemovingMapPin = true;
    _mapPinActionError = null;
    notifyListeners();

    try {
      await _mapApi.removeMapItem(mapItemId);
      _mapItems = _mapItems
          .where((candidate) => candidate.effectiveMapItemId != mapItemId)
          .toList(growable: false);
      if (_selectedMapItem?.effectiveMapItemId == mapItemId) {
        _selectedMapItem = null;
      }
      if (_totalPinnedLocations > 0) {
        _totalPinnedLocations -= 1;
      }
      if (_visiblePinnedLocations > 0) {
        _visiblePinnedLocations -= 1;
      }
      _placeSearchResults = _placeSearchResults
          .where((result) => result.mapItem?.effectiveMapItemId != mapItemId)
          .toList(growable: false);
      _mapPinActionError = null;
      return true;
    } catch (e) {
      _mapPinActionError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not remove this map pin right now.',
      );
      return false;
    } finally {
      _isRemovingMapPin = false;
      notifyListeners();
    }
  }

  void clearPlaceSearch() {
    _placeSearchRequestId += 1;
    _placeSearchResults = const [];
    _isSearchingPlaces = false;
    _placeSearchError = null;
    _mapPinActionError = null;
    _lastPlaceQuery = '';
    _placeSearchSessionToken = '';
    notifyListeners();
  }

  void _upsertMapItem(MapItem item) {
    final next = List<MapItem>.from(_mapItems);
    final index = next.indexWhere(
      (candidate) => candidate.effectiveMapItemId == item.effectiveMapItemId,
    );
    if (index == -1) {
      next.add(item);
    } else {
      next[index] = item;
    }
    _mapItems = next;
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
