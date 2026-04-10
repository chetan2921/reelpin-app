import '../models/reel.dart';
import '../models/search_result.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/reel_store.dart';

/// Single Source of Truth (SSOT) for reel data.
/// Handles caching and data transformation.
class ReelRepository {
  final ApiService _apiService;
  final ReelStore _reelStore;
  final AuthService _authService;

  // In-memory cache
  List<Reel> _cachedReels = [];
  DateTime? _lastFetched;

  ReelRepository(this._apiService, this._reelStore, this._authService);

  String get _currentUserId {
    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('No authenticated user found.');
    }
    return userId;
  }

  /// Fetch all reels, using cache if fresh (< 30s).
  Future<List<Reel>> getReels({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cacheValid =
        _lastFetched != null &&
        now.difference(_lastFetched!).inSeconds < 30 &&
        !forceRefresh;

    if (cacheValid && _cachedReels.isNotEmpty) {
      return _cachedReels;
    }

    _cachedReels = await _reelStore.fetchReels(userId: _currentUserId);
    _lastFetched = now;
    return _cachedReels;
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
  Future<Reel> getReel(String reelId) async {
    // Check cache first
    final cached = _cachedReels.where((r) => r.id == reelId);
    if (cached.isNotEmpty) return cached.first;
    return _reelStore.fetchReel(reelId: reelId, userId: _currentUserId);
  }

  /// Process a reel from URL and add to cache.
  Future<Reel> processReel(String url) async {
    final reel = await _apiService.processReel(url, userId: _currentUserId);
    _cachedReels.removeWhere((existing) => existing.id == reel.id);
    _cachedReels.insert(0, reel);
    _lastFetched = DateTime.now();
    return reel;
  }

  /// Delete a reel and remove from cache.
  Future<void> deleteReel(String reelId) async {
    await _reelStore.deleteReel(reelId: reelId, userId: _currentUserId);
    _cachedReels.removeWhere((r) => r.id == reelId);
  }

  /// RAG search.
  Future<List<SearchResult>> search(String query, {String? category}) async {
    try {
      final remote = await _apiService.searchReels(
        query,
        userId: _currentUserId,
        category: category,
      );
      if (remote.isNotEmpty) {
        return remote;
      }
    } catch (_) {
      // Fall back to a local semantic-ish search when backend search fails.
    }

    return _searchLocally(query, category: category);
  }

  /// Invalidate cache.
  void clearCache() {
    _cachedReels.clear();
    _lastFetched = null;
  }

  Future<List<SearchResult>> _searchLocally(
    String query, {
    String? category,
  }) async {
    final reels = await getReels(forceRefresh: true);
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    final filtered = category == null
        ? reels
        : reels
            .where(
              (reel) =>
                  reel.category.toLowerCase() == category.toLowerCase() ||
                  reel.subCategory.toLowerCase() == category.toLowerCase(),
            )
            .toList();

    final matches = <SearchResult>[];
    for (final reel in filtered) {
      final score = _scoreReel(reel, normalizedQuery, tokens);
      if (score > 0) {
        matches.add(
          SearchResult(
            reel: reel,
            relevanceScore: score.clamp(0.0, 0.99),
          ),
        );
      }
    }

    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(12).toList();
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
      if (category.contains(token) || subCategory.contains(token)) score += 0.05;
    }

    return score;
  }
}
