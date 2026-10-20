import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/http/map_http.dart';
import 'package:reelpin/data_models/map/map_bounds.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/utils/error_message.dart';

class MapViewModel extends ChangeNotifier {
  final MapHttp _mapHttp;

  MapViewModel(this._mapHttp);

  /// How long the camera must stay settled before its viewport is queried, so
  /// a fling followed by a nudge is one request.
  static const viewportDebounce = Duration(milliseconds: 400);

  /// The my-location button waits on the nearby lookup, so it gives up
  /// quickly and recentres without it.
  static const _nearbyTimeout = Duration(seconds: 3);

  List<MapItem> _mapItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedCategory;
  MapItem? _selectedMapItem;
  MapBounds? _viewport;
  Timer? _viewportTimer;
  int _pinsRequestId = 0;
  MapBounds? _loadingBounds;
  String? _loadingCategory;
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

  /// The pins in the current viewport and category.
  int get totalPinnedLocations => _mapItems.length;
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

  /// Restores the last saved map snapshot so pins are on screen before the
  /// network request comes back. No-ops once live data has arrived.
  Future<void> hydrateFromCache() async {
    if (_mapItems.isNotEmpty || _selectedCategory != null) return;

    final payload = await ContentCache.instance.read(
      ContentCacheKeys.mapOverview,
    );
    if (payload == null) return;
    if (_mapItems.isNotEmpty || _selectedCategory != null) return;

    try {
      final response = MapResponse.fromJson(payload);
      if (response.mapItems.isEmpty) return;

      _mapItems = response.mapItems;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached map data could not be restored: $e');
      unawaited(ContentCache.instance.invalidate(ContentCacheKeys.mapOverview));
    }
  }

  /// Loads the pins for the last viewport the camera reported, or the whole
  /// world before it has reported one. A newer query supersedes one in
  /// flight; the same query in flight is not sent twice.
  ///
  /// The selected pin is kept even when it falls outside the new viewport:
  /// panning away is not a reason to close its sheet.
  Future<void> loadMapReels({bool forceRefresh = false}) async {
    _viewportTimer?.cancel();
    final bounds = _viewport ?? MapBounds.world;
    final category = _selectedCategory;
    if (_isLoading &&
        _loadingBounds == bounds &&
        _loadingCategory == category) {
      return;
    }

    final requestId = ++_pinsRequestId;
    _loadingBounds = bounds;
    _loadingCategory = category;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _mapHttp.getMapData(
        bounds: bounds,
        category: category,
      );
      if (requestId != _pinsRequestId) return;
      _mapItems = response.mapItems;
    } catch (e) {
      if (requestId != _pinsRequestId) return;
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load map data right now.',
      );
    } finally {
      if (requestId == _pinsRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Called each time the camera settles. The query waits for
  /// [viewportDebounce] so only the last of several quick settles is sent.
  void updateViewport(MapBounds bounds) {
    if (!bounds.hasArea || bounds == _viewport) return;
    _viewport = bounds;
    _viewportTimer?.cancel();
    _viewportTimer = Timer(viewportDebounce, () {
      unawaited(loadMapReels());
    });
  }

  /// The saved places nearest a point, for framing the my-location recenter.
  /// An empty list means "just recenter": the button still has to work when
  /// this lookup fails or is slow, so the failure is logged, not shown.
  Future<List<MapItem>> nearbyMapItems(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _mapHttp
          .getNearbyPins(latitude: latitude, longitude: longitude)
          .timeout(_nearbyTimeout);
      return response.mapItems;
    } catch (e) {
      AppLogger.error('Nearby map pins could not be loaded: $e');
      return const [];
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

  /// Clears this user's map. The viewport is the camera's, not the user's, so
  /// it is kept for the next load.
  void reset() {
    _viewportTimer?.cancel();
    _pinsRequestId += 1;
    _mapItems = const [];
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    _selectedCategory = null;
    _selectedMapItem = null;
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
      final response = await _mapHttp.searchMapPlaces(
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
      final item = await _mapHttp.pinMapPlace(
        googlePlaceId,
        sessionToken: _placeSearchSessionToken,
      );
      _upsertMapItem(item);
      _selectedMapItem = item;
      _placeSearchSessionToken = '';
      _mapPinActionError = null;
      unawaited(ContentCache.instance.invalidate(ContentCacheKeys.mapOverview));
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

  /// Hides a content pin or deletes a manual one, through the id form
  /// [MapItem.effectiveMapItemId] carries for its kind.
  Future<bool> removeMapItem(MapItem item) async {
    if (!item.canHide && !item.canRemove) return false;
    final mapItemId = item.effectiveMapItemId.trim();
    if (mapItemId.isEmpty) return false;

    _isRemovingMapPin = true;
    _mapPinActionError = null;
    notifyListeners();

    try {
      await _mapHttp.removeMapItem(mapItemId);
      _mapItems = _mapItems
          .where((candidate) => candidate.effectiveMapItemId != mapItemId)
          .toList(growable: false);
      if (_selectedMapItem?.effectiveMapItemId == mapItemId) {
        _selectedMapItem = null;
      }
      _placeSearchResults = _placeSearchResults
          .where((result) => result.mapItem?.effectiveMapItemId != mapItemId)
          .toList(growable: false);
      _mapPinActionError = null;
      unawaited(ContentCache.instance.invalidate(ContentCacheKeys.mapOverview));
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

  @override
  void dispose() {
    _viewportTimer?.cancel();
    super.dispose();
  }
}
