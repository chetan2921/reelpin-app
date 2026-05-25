import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/discover_response.dart';
import '../models/library_stats.dart';
import '../models/map_response.dart';
import '../models/processing_job.dart';
import '../models/reel.dart';
import '../models/reel_category_filters.dart';
import '../models/search_response.dart';
import '../models/user_entitlement.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SearchCancelledException implements Exception {
  const SearchCancelledException();
}

class ReelRepository extends ChangeNotifier {
  static const _pageSize = 25;

  final ApiService _apiService;
  final AuthService _authService;

  List<Reel> _cachedReels = [];
  int _nextOffset = 0;
  String? _nextCursor;
  bool _hasMoreReels = true;
  bool _hasHydratedCache = false;
  int _totalCount = 0;
  Future<void>? _initialLoadFuture;
  Future<void>? _loadMoreFuture;
  http.Client? _activeSearchClient;
  SearchMode? _lastSearchMode;
  int _lastSearchTotal = 0;

  ReelRepository(this._apiService, this._authService);

  String get _currentUserId {
    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('No authenticated user found.');
    }
    return userId;
  }

  List<Reel> get cachedReels => List.unmodifiable(_cachedReels);
  bool get hasMoreReels => _hasMoreReels;
  bool get hasHydratedCache => _hasHydratedCache;
  int get totalCount => _totalCount;
  SearchMode? get lastSearchMode => _lastSearchMode;
  int get lastSearchTotal => _lastSearchTotal;

  Future<void> hydrateCache() async {
    _hasHydratedCache = true;
  }

  Future<void> loadInitialReels({
    bool forceRefresh = false,
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
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    await hydrateCache();

    await _fetchAndStorePage(
      reset: true,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      sort: sort,
    );
  }

  Future<void> loadMoreReels({
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
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    await hydrateCache();
    if (!_hasMoreReels) {
      return;
    }

    await _fetchAndStorePage(
      reset: false,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      sort: sort,
    );
  }

  Future<void> _fetchAndStorePage({
    required bool reset,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    final page = await _apiService.getReelsPage(
      userId: _currentUserId,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
      offset: reset ? 0 : _nextOffset,
      cursor: reset ? null : _nextCursor,
      limit: _pageSize,
      sort: sort,
    );
    _nextOffset = page.nextOffset ?? page.offset;
    _nextCursor = page.nextCursor;
    _hasMoreReels = page.hasMore;
    _totalCount = page.totalCount;
    _cachedReels = reset ? page.reels : [..._cachedReels, ...page.reels];
    notifyListeners();
  }

  Future<List<Reel>> getReels({
    bool forceRefresh = false,
    String? category,
    String? subcategory,
    String? savedDate,
  }) async {
    await loadInitialReels(
      forceRefresh: forceRefresh,
      category: category,
      subcategory: subcategory,
      savedDate: savedDate,
    );
    return cachedReels;
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
    await loadInitialReels(forceRefresh: true);
    return reel;
  }

  Future<ProcessingJob> enqueueReelProcessing(String url) {
    return _apiService.enqueueReelProcessing(url, userId: _currentUserId);
  }

  Future<ReelCategoryFiltersResponse> getCategoryFilters({
    String? category,
    String? subcategory,
  }) {
    return _apiService.getReelCategoryFilters(
      userId: _currentUserId,
      category: category,
      subcategory: subcategory,
    );
  }

  Future<MapResponse> getMapData({String? category}) {
    return _apiService.getMapData(category: category);
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
    _cachedReels.clear();
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
