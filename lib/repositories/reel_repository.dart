import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:reelpin/data_models/discover/discover_response.dart';
import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/data_models/discover/search_response.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/services/auth/auth_service.dart';

class SearchCancelledException implements Exception {
  const SearchCancelledException();
}

class ReelRepository extends ChangeNotifier {
  static const _pageSize = 25;

  final ApiClient _apiService;
  final AuthService _authService;
  final ContentCache _contentCache;

  List<Reel> _cachedReels = [];
  String? _cacheUserId;
  int _nextOffset = 0;
  String? _nextCursor;
  bool _hasMoreReels = true;
  bool _hasHydratedCache = false;
  int _totalCount = 0;
  Future<void>? _hydrationFuture;
  Future<void>? _initialLoadFuture;
  Future<void>? _loadMoreFuture;
  http.Client? _activeSearchClient;
  SearchMode? _lastSearchMode;
  int _lastSearchTotal = 0;

  ReelRepository(
    this._apiService,
    this._authService, {
    ContentCache? contentCache,
  }) : _contentCache = contentCache ?? ContentCache.instance;

  String get _currentUserId {
    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('No authenticated user found.');
    }
    return userId;
  }

  List<Reel> get cachedReels => List.unmodifiable(_cachedReels);
  String? get cacheUserId => _cacheUserId;
  bool get hasMoreReels => _hasMoreReels;
  bool get hasHydratedCache => _hasHydratedCache;
  int get totalCount => _totalCount;
  SearchMode? get lastSearchMode => _lastSearchMode;
  int get lastSearchTotal => _lastSearchTotal;

  /// Fills the in-memory list from the last saved snapshot so the first frame
  /// after a cold start already has content. Runs at most once per session and
  /// never overwrites data that a live request has already delivered.
  Future<void> hydrateCache() {
    if (_hasHydratedCache) {
      return _hydrationFuture ?? Future<void>.value();
    }

    final existing = _hydrationFuture;
    if (existing != null) return existing;

    final future = _hydrateCache();
    _hydrationFuture = future;
    return future.whenComplete(() {
      if (identical(_hydrationFuture, future)) {
        _hydrationFuture = null;
      }
    });
  }

  Future<void> _hydrateCache() async {
    if (_cachedReels.isNotEmpty) {
      _hasHydratedCache = true;
      return;
    }

    String? userId;
    try {
      userId = _currentUserId;
    } catch (_) {
      // Signed out — nothing user-scoped to restore.
      _hasHydratedCache = true;
      return;
    }

    final payload = await _contentCache.read(ContentCacheKeys.reelsFirstPage);
    _hasHydratedCache = true;
    if (payload == null) return;
    // A live response landed while we were reading from disk; it wins.
    if (_cachedReels.isNotEmpty) return;

    try {
      final page = ReelPage.fromJson(payload);
      if (page.reels.isEmpty) return;

      _cachedReels = page.reels;
      _nextOffset = page.nextOffset ?? page.offset;
      _nextCursor = page.nextCursor;
      _hasMoreReels = page.hasMore;
      _totalCount = page.totalCount;
      _cacheUserId = userId;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached reels could not be restored: $e');
      unawaited(_contentCache.invalidate(ContentCacheKeys.reelsFirstPage));
    }
  }

  Future<void> loadInitialReels({
    bool forceRefresh = false,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) {
    if (_initialLoadFuture != null) {
      return _initialLoadFuture!;
    }

    final future = _loadInitialReels(
      forceRefresh: forceRefresh,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      sort: sort,
    );
    _initialLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_initialLoadFuture, future)) {
        _initialLoadFuture = null;
      }
    });
  }

  Future<void> _loadInitialReels({
    required bool forceRefresh,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    // The snapshot only ever holds the unfiltered first page, so restoring it
    // under an active filter would flash the wrong content.
    if (!_hasFilters(platform, category, subcategory, savedDate, sort)) {
      await hydrateCache();
    }

    await _fetchAndStorePage(
      reset: true,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      sort: sort,
    );
  }

  Future<void> loadMoreReels({
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) {
    if (_loadMoreFuture != null) {
      return _loadMoreFuture!;
    }
    if (!_hasMoreReels) {
      return Future<void>.value();
    }

    final future = _loadMoreReelsInternal(
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      sort: sort,
    );
    _loadMoreFuture = future;
    return future.whenComplete(() {
      if (identical(_loadMoreFuture, future)) {
        _loadMoreFuture = null;
      }
    });
  }

  Future<void> _loadMoreReelsInternal({
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    if (!_hasFilters(platform, category, subcategory, savedDate, sort)) {
      await hydrateCache();
    }
    if (!_hasMoreReels) {
      return;
    }

    await _fetchAndStorePage(
      reset: false,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      sort: sort,
    );
  }

  Future<void> _fetchAndStorePage({
    required bool reset,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    final requestUserId = _currentUserId;
    final page = await _apiService.getReelsPage(
      userId: requestUserId,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      offset: reset ? 0 : _nextOffset,
      cursor: reset ? null : _nextCursor,
      limit: _pageSize,
      sort: sort,
    );
    if (_currentUserId != requestUserId) {
      return;
    }
    _nextOffset = page.nextOffset ?? page.offset;
    _nextCursor = page.nextCursor;
    _hasMoreReels = page.hasMore;
    _totalCount = page.totalCount;
    _cacheUserId = requestUserId;
    _cachedReels = reset ? page.reels : [..._cachedReels, ...page.reels];
    notifyListeners();
  }

  Future<List<Reel>> getReels({
    bool forceRefresh = false,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
  }) async {
    await loadInitialReels(
      forceRefresh: forceRefresh,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
    );
    return cachedReels;
  }

  Future<ReelPage> getReelsPage({
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = _pageSize,
    String? sort,
  }) {
    return _apiService.getReelsPage(
      userId: _currentUserId,
      platform: platform,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      offset: offset,
      cursor: cursor,
      limit: limit,
      sort: sort,
    );
  }

  Future<Reel> getReel(String reelId, {bool forceRefresh = false}) async {
    final reel = await _apiService.getReel(reelId);
    return reel;
  }

  Future<Reel> processReel(
    String url, {
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    final reel = await _apiService.processReel(
      url,
      userId: _currentUserId,
      onJobUpdate: onJobUpdate,
    );
    await _contentCache.invalidateContent();
    await loadInitialReels(forceRefresh: true);
    return reel;
  }

  Future<ProcessingJob> enqueueReelProcessing(String url) {
    return _apiService.enqueueReelProcessing(url, userId: _currentUserId);
  }

  Future<ReelFiltersResponse> getFilters({
    String? platform,
    String? category,
    String? subcategory,
  }) {
    return _apiService.getReelFilters(
      userId: _currentUserId,
      platform: platform,
      category: category,
      subcategory: subcategory,
    );
  }

  Future<MapResponse> getMapData({String? category}) {
    return _apiService.getMapData(category: category);
  }

  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
  }) {
    return _apiService.searchMapPlaces(
      query,
      category: category,
      sessionToken: sessionToken,
    );
  }

  Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken}) {
    return _apiService.pinMapPlace(googlePlaceId, sessionToken: sessionToken);
  }

  Future<void> removeMapItem(String mapItemId) {
    return _apiService.removeMapItem(mapItemId);
  }

  Future<DiscoverResponse> getDiscover({
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = _pageSize,
  }) {
    return _apiService.getDiscover(
      savedDate: savedDate,
      offset: offset,
      cursor: cursor,
      limit: limit,
    );
  }

  Future<LibraryStats> getLibraryStats() {
    return _apiService.getLibraryStats();
  }

  Future<void> deleteReel(String reelId) async {
    await _apiService.deleteReel(reelId);
    await _contentCache.invalidateContent();
    await loadInitialReels(forceRefresh: true);
  }

  Future<SearchResponse> search(
    String query, {
    String? category,
    String? subcategory,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const SearchResponse(
        query: '',
        results: [],
        total: 0,
        searchMode: SearchMode.keyword,
      );
    }

    cancelActiveSearch();
    final searchClient = http.Client();
    _activeSearchClient = searchClient;

    try {
      final remote = await _apiService.searchReels(
        normalizedQuery,
        userId: _currentUserId,
        category: category,
        subcategory: subcategory,
        client: searchClient,
      );
      if (!_isActiveSearchClient(searchClient)) {
        throw const SearchCancelledException();
      }
      _lastSearchMode = remote.searchMode;
      _lastSearchTotal = remote.total;
      notifyListeners();
      return remote;
    } finally {
      if (_isActiveSearchClient(searchClient)) {
        _activeSearchClient = null;
      }
      searchClient.close();
    }
  }

  void clearCache() {
    cancelActiveSearch();
    _cachedReels = [];
    _cacheUserId = null;
    _nextOffset = 0;
    _nextCursor = null;
    _hasMoreReels = true;
    _hasHydratedCache = false;
    _totalCount = 0;
    _lastSearchMode = null;
    _lastSearchTotal = 0;
    notifyListeners();
  }

  Future<void> clearUserCache() async {
    clearCache();
    // The visible data was just dropped because it no longer applies to this
    // user, so the snapshot behind it must go too.
    await _contentCache.invalidateContent();
  }

  bool _hasFilters(
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  ) {
    bool isSet(String? value) => value != null && value.trim().isNotEmpty;
    return isSet(platform) ||
        isSet(category) ||
        isSet(subcategory) ||
        isSet(savedDate) ||
        isSet(sort);
  }

  void cancelActiveSearch() {
    final activeClient = _activeSearchClient;
    _activeSearchClient = null;
    activeClient?.close();
  }

  bool _isActiveSearchClient(http.Client client) =>
      identical(_activeSearchClient, client);

  @override
  void dispose() {
    cancelActiveSearch();
    super.dispose();
  }
}
