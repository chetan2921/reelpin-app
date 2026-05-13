import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/reel.dart';
import '../models/processing_job.dart';
import '../models/reel_category_filters.dart';
import '../models/search_result.dart';
import '../models/user_entitlement.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/reel_store.dart';

/// Single Source of Truth (SSOT) for reel data.
/// Handles caching and data transformation.
class SearchCancelledException implements Exception {
  const SearchCancelledException();
}

class _CachedSearchResults {
  const _CachedSearchResults({required this.results, required this.cachedAt});

  final List<SearchResult> results;
  final DateTime cachedAt;
}

class ReelRepository extends ChangeNotifier {
  static const _cacheTtl = Duration(seconds: 30);
  static const _pageSize = 25;
  static const _searchCacheTtl = Duration(minutes: 2);

  final ApiService _apiService;
  final ReelStore _reelStore;
  final AuthService _authService;

  // In-memory cache
  List<Reel> _cachedReels = [];
  DateTime? _lastFetched;
  int _nextOffset = 0;
  bool _hasMoreReels = true;
  bool _hasHydratedCache = false;
  Future<void>? _initialLoadFuture;
  Future<void>? _loadMoreFuture;
  final Map<String, _CachedSearchResults> _searchCache = {};
  http.Client? _activeSearchClient;
  SearchMode? _lastSearchMode;

  ReelRepository(this._apiService, this._reelStore, this._authService);

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
  SearchMode? get lastSearchMode => _lastSearchMode;

  bool get _cacheIsFresh {
    if (_lastFetched == null) return false;
    return DateTime.now().difference(_lastFetched!) < _cacheTtl;
  }

  Future<void> hydrateCache() async {
    if (_hasHydratedCache) {
      return;
    }

    final snapshot = await _reelStore.loadCachedReels(userId: _currentUserId);
    _hasHydratedCache = true;
    if (snapshot == null) {
      return;
    }

    _cachedReels = List<Reel>.from(snapshot.reels);
    _nextOffset = snapshot.nextOffset;
    _hasMoreReels = snapshot.hasMore;
    _lastFetched = snapshot.lastFetchedAt?.toLocal();
    notifyListeners();
  }

  Future<void> loadInitialReels({bool forceRefresh = false}) {
    if (_initialLoadFuture != null) {
      return _initialLoadFuture!;
    }

    final future = _loadInitialReels(forceRefresh: forceRefresh);
    _initialLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_initialLoadFuture, future)) {
        _initialLoadFuture = null;
      }
    });
  }

  Future<void> _loadInitialReels({bool forceRefresh = false}) async {
    await hydrateCache();

    final shouldRefresh =
        forceRefresh || _cachedReels.isEmpty || !_cacheIsFresh;
    if (!shouldRefresh) {
      return;
    }

    await _fetchAndStorePage(reset: true);
  }

  Future<void> loadMoreReels() {
    if (_loadMoreFuture != null) {
      return _loadMoreFuture!;
    }
    if (!_hasMoreReels) {
      return Future<void>.value();
    }

    final future = _loadMoreReelsInternal();
    _loadMoreFuture = future;
    return future.whenComplete(() {
      if (identical(_loadMoreFuture, future)) {
        _loadMoreFuture = null;
      }
    });
  }

  Future<void> _loadMoreReelsInternal() async {
    await hydrateCache();
    if (!_hasMoreReels) {
      return;
    }

    await _fetchAndStorePage(reset: false);
  }

  Future<void> _fetchAndStorePage({required bool reset}) async {
    final requestLimit = reset ? _pageSize : _nextOffset + _pageSize;
    final reels = await _apiService.getReels(
      userId: _currentUserId,
      limit: requestLimit,
    );
    final fetchedAt = DateTime.now();
    _lastFetched = fetchedAt;
    _nextOffset = reels.length;
    _hasMoreReels = reels.length >= requestLimit;
    if (!reset && reels.length <= _cachedReels.length) {
      _hasMoreReels = false;
    }
    _cachedReels = _mergeReels(
      reels,
      existing: reset ? _cachedReels : _cachedReels,
      append: !reset,
    );
    _searchCache.clear();
    await _persistCache();
    notifyListeners();
  }

  List<Reel> _mergeReels(
    List<Reel> incoming, {
    required List<Reel> existing,
    required bool append,
  }) {
    final mergedById = <String, Reel>{};

    if (!append) {
      for (final reel in incoming) {
        mergedById[reel.id] = reel;
      }
    } else {
      for (final reel in existing) {
        mergedById[reel.id] = reel;
      }
      for (final reel in incoming) {
        mergedById[reel.id] = reel;
      }
    }

    final merged = mergedById.values.toList();
    merged.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt ?? '');
      final bDate = DateTime.tryParse(b.createdAt ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return merged;
  }

  Future<void> _persistCache() {
    return _reelStore.saveCachedReels(
      userId: _currentUserId,
      reels: _cachedReels,
      nextOffset: _nextOffset,
      hasMore: _hasMoreReels,
      lastFetchedAt: _lastFetched ?? DateTime.now(),
    );
  }

  /// Fetch all reels, using cache if fresh.
  Future<List<Reel>> getReels({bool forceRefresh = false}) async {
    await loadInitialReels(forceRefresh: forceRefresh);
    return cachedReels;
  }

  /// Get reels filtered by category.
  Future<List<Reel>> getReelsByCategory(String category) async {
    final all = await getReels();
    return all.where((r) => r.category == category).toList();
  }

  /// Get only reels that have map-pinnable locations.
  Future<List<Reel>> getReelsWithLocations({bool forceRefresh = false}) async {
    final all = await getReels(forceRefresh: forceRefresh);
    return all.where((r) => r.hasMapLocations).toList();
  }

  /// Get a single reel by ID.
  Future<Reel> getReel(String reelId, {bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = _cachedReels.where((r) => r.id == reelId);
      if (cached.isNotEmpty) {
        return cached.first;
      }
    }

    final reel = await _apiService.getReel(reelId);
    _cachedReels = [
      reel,
      ..._cachedReels.where((existing) => existing.id != reel.id),
    ];
    await _reelStore.cacheReel(userId: _currentUserId, reel: reel);
    notifyListeners();
    return reel;
  }

  /// Process a reel from URL and add to cache.
  Future<Reel> processReel(
    String url, {
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    final reel = await _apiService.processReel(
      url,
      userId: _currentUserId,
      onJobUpdate: onJobUpdate,
    );
    _cachedReels = [
      reel,
      ..._cachedReels.where((existing) => existing.id != reel.id),
    ];
    _lastFetched = DateTime.now();
    _nextOffset = _cachedReels.length > _nextOffset
        ? _cachedReels.length
        : _nextOffset;
    _searchCache.clear();
    await _reelStore.cacheReel(userId: _currentUserId, reel: reel);
    notifyListeners();
    return reel;
  }

  Future<ProcessingJob> enqueueReelProcessing(String url) {
    return _apiService.enqueueReelProcessing(url, userId: _currentUserId);
  }

  Future<ReelCategoryFiltersResponse> getCategoryFilters() {
    return _apiService.getReelCategoryFilters(userId: _currentUserId);
  }

  /// Delete a reel and remove from cache.
  Future<void> deleteReel(String reelId) async {
    await _apiService.deleteReel(reelId);
    _cachedReels = _cachedReels.where((reel) => reel.id != reelId).toList();
    if (_nextOffset > 0) {
      _nextOffset -= 1;
    }
    _searchCache.clear();
    await _reelStore.removeCachedReel(userId: _currentUserId, reelId: reelId);
    notifyListeners();
  }

  /// RAG search.
  Future<List<SearchResult>> search(
    String query, {
    String? category,
    String? subcategory,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final cacheKey = _searchCacheKey(
      normalizedQuery,
      category: category,
      subcategory: subcategory,
    );
    final cachedResults = _searchCache[cacheKey];
    if (cachedResults != null &&
        DateTime.now().difference(cachedResults.cachedAt) < _searchCacheTtl) {
      return cachedResults.results;
    }

    cancelActiveSearch();
    final searchClient = http.Client();
    _activeSearchClient = searchClient;

    try {
      List<SearchResult>? remoteResults;
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
        remoteResults = remote.results;
      } on SearchCancelledException {
        rethrow;
      } catch (_) {
        // Fall back to a local semantic-ish search when backend search fails.
      }

      if (!_isActiveSearchClient(searchClient)) {
        throw const SearchCancelledException();
      }

      final local = await _searchLocally(
        normalizedQuery,
        category: category,
        subcategory: subcategory,
      );
      if (!_isActiveSearchClient(searchClient)) {
        throw const SearchCancelledException();
      }
      if (remoteResults == null) {
        _lastSearchMode = null;
        _storeSearchCache(cacheKey, local);
        return local;
      }

      final combined = _mergeSearchResults(remoteResults, local);
      _storeSearchCache(cacheKey, combined);
      return combined;
    } finally {
      if (_isActiveSearchClient(searchClient)) {
        _activeSearchClient = null;
      }
      searchClient.close();
    }
  }

  /// Invalidate cache.
  void clearCache() {
    cancelActiveSearch();
    _cachedReels.clear();
    _lastFetched = null;
    _nextOffset = 0;
    _hasMoreReels = true;
    _hasHydratedCache = false;
    _searchCache.clear();
    _lastSearchMode = null;
    notifyListeners();
  }

  Future<void> clearUserCache() async {
    final userId = _authService.currentUser?.id;
    clearCache();
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    await _reelStore.clearCachedReels(userId: userId);
  }

  void cancelActiveSearch() {
    final activeClient = _activeSearchClient;
    _activeSearchClient = null;
    activeClient?.close();
  }

  Future<List<SearchResult>> _searchLocally(
    String query, {
    String? category,
    String? subcategory,
  }) async {
    await hydrateCache();
    if (_cachedReels.isEmpty) {
      await loadInitialReels();
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final sqliteCandidates = await _reelStore.searchCachedReels(
      userId: _currentUserId,
      query: normalizedQuery,
      category: category,
      subcategory: subcategory,
    );

    final candidateSource = sqliteCandidates.isNotEmpty
        ? sqliteCandidates
        : cachedReels
              .where((reel) {
                if (category != null &&
                    reel.category.toLowerCase() != category.toLowerCase()) {
                  return false;
                }
                if (subcategory != null &&
                    reel.subCategory.toLowerCase() !=
                        subcategory.toLowerCase()) {
                  return false;
                }
                return true;
              })
              .toList(growable: false);

    final matches = <SearchResult>[];
    for (final reel in candidateSource) {
      final score = _scoreReel(reel, normalizedQuery, tokens);
      if (score > 0) {
        matches.add(
          SearchResult(reel: reel, relevanceScore: score.clamp(0.0, 0.99)),
        );
      }
    }

    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(12).toList();
  }

  List<SearchResult> _mergeSearchResults(
    List<SearchResult> remote,
    List<SearchResult> local,
  ) {
    final byReelId = <String, SearchResult>{};
    for (final result in remote) {
      byReelId[result.reel.id] = result;
    }
    for (final result in local) {
      final existing = byReelId[result.reel.id];
      if (existing == null || result.relevanceScore > existing.relevanceScore) {
        byReelId[result.reel.id] = result;
      }
    }

    final merged = byReelId.values.toList(growable: false);
    merged.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return merged.take(12).toList(growable: false);
  }

  double _scoreReel(Reel reel, String query, List<String> tokens) {
    double score = 0;

    final title = reel.title.toLowerCase();
    final summary = reel.summary.toLowerCase();
    final transcript = reel.transcript.toLowerCase();
    final category = reel.category.toLowerCase();
    final subCategory = reel.subCategory.toLowerCase();
    final facts = reel.keyFacts.join(' ').toLowerCase();
    final people = reel.peopleMentioned.join(' ').toLowerCase();
    final actions = reel.actionableItems.join(' ').toLowerCase();
    final locations = reel.locations
        .expand((location) => [location.name, location.address ?? ''])
        .join(' ')
        .toLowerCase();

    if (title.contains(query)) score += 0.45;
    if (summary.contains(query)) score += 0.25;
    if (facts.contains(query)) score += 0.2;
    if (locations.contains(query)) score += 0.35;
    if (people.contains(query)) score += 0.18;
    if (actions.contains(query)) score += 0.15;
    if (category.contains(query) || subCategory.contains(query)) score += 0.22;

    for (final token in tokens) {
      if (token.length < 2) continue;
      if (title.contains(token)) score += 0.12;
      if (summary.contains(token)) score += 0.06;
      if (transcript.contains(token)) score += 0.03;
      if (facts.contains(token)) score += 0.05;
      if (locations.contains(token)) score += 0.08;
      if (people.contains(token)) score += 0.04;
      if (actions.contains(token)) score += 0.03;
      if (category.contains(token) || subCategory.contains(token)) {
        score += 0.05;
      }
    }

    return score;
  }

  bool _isActiveSearchClient(http.Client client) =>
      identical(_activeSearchClient, client);

  String _searchCacheKey(
    String query, {
    String? category,
    String? subcategory,
  }) {
    return [
      query.trim().toLowerCase(),
      category?.trim().toLowerCase() ?? '',
      subcategory?.trim().toLowerCase() ?? '',
    ].join('|');
  }

  void _storeSearchCache(String cacheKey, List<SearchResult> results) {
    _searchCache[cacheKey] = _CachedSearchResults(
      results: List<SearchResult>.unmodifiable(results),
      cachedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    cancelActiveSearch();
    super.dispose();
  }
}
