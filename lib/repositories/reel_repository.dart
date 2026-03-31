import '../models/reel.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';

/// Single Source of Truth (SSOT) for reel data.
/// Handles caching and data transformation.
class ReelRepository {
  final ApiService _apiService;

  // In-memory cache
  List<Reel> _cachedReels = [];
  DateTime? _lastFetched;

  ReelRepository(this._apiService);

  /// Fetch all reels, using cache if fresh (< 30s).
  Future<List<Reel>> getReels({
    String? userId,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cacheValid =
        _lastFetched != null &&
        now.difference(_lastFetched!).inSeconds < 30 &&
        !forceRefresh;

    if (cacheValid && _cachedReels.isNotEmpty) {
      return _cachedReels;
    }

    _cachedReels = await _apiService.getReels(userId: userId);
    _lastFetched = now;
    return _cachedReels;
  }

  /// Get reels filtered by category.
  Future<List<Reel>> getReelsByCategory(
    String category, {
    String? userId,
  }) async {
    final all = await getReels(userId: userId);
    return all.where((r) => r.category == category).toList();
  }

  /// Get only reels that have map-pinnable locations.
  Future<List<Reel>> getReelsWithLocations({
    String? userId,
    bool forceRefresh = false,
  }) async {
    final all = await getReels(userId: userId, forceRefresh: forceRefresh);
    return all.where((r) => r.hasMapLocations).toList();
  }

  /// Get a single reel by ID.
  Future<Reel> getReel(String reelId) async {
    // Check cache first
    final cached = _cachedReels.where((r) => r.id == reelId);
    if (cached.isNotEmpty) return cached.first;
    return _apiService.getReel(reelId);
  }

  /// Process a reel from URL and add to cache.
  Future<Reel> processReel(String url, {String userId = 'default-user'}) async {
    final reel = await _apiService.processReel(url, userId: userId);
    _cachedReels.insert(0, reel);
    return reel;
  }

  /// Delete a reel and remove from cache.
  Future<void> deleteReel(String reelId) async {
    await _apiService.deleteReel(reelId);
    _cachedReels.removeWhere((r) => r.id == reelId);
  }

  /// RAG search.
  Future<List<SearchResult>> search(
    String query, {
    String userId = 'default-user',
    String? category,
  }) async {
    return _apiService.searchReels(query, userId: userId, category: category);
  }

  /// Invalidate cache.
  void clearCache() {
    _cachedReels.clear();
    _lastFetched = null;
  }
}
