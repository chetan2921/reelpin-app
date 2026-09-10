import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/api_exception.dart';

/// Fills the gap between what an answer cites and what the paginated
/// library already holds.
///
/// The backend searches the user's whole library and can cite any reel, but
/// `ReelRepository.cachedReels` only holds what has actually been paged into
/// memory — so a cited id the user hasn't scrolled to yet is not "deleted",
/// it's just not cached locally yet. This fetches such ids on demand, one at
/// a time, and remembers the result for as long as this cache is kept alive
/// (one instance per chat screen), so revisiting a thread — or a later
/// message citing the same reel — never re-fetches it.
class ChatReelCache {
  ChatReelCache(this._fetchReel);

  final Future<Reel> Function(String reelId) _fetchReel;

  final Map<String, Reel> _resolved = {};
  final Map<String, Future<Reel?>> _inFlight = {};

  /// Ids the backend has told us don't exist (a 404). Distinct from
  /// `_resolved` because there's no `Reel` to show, but a rebuild must still
  /// know not to ask again — otherwise every rebuild of the enclosing screen
  /// re-fetches a reel that's been permanently deleted. A transient failure
  /// (no connectivity, a 500) is *not* recorded here, so it can still be
  /// retried by a later resolve — just not by the rebuild that caused this
  /// one, since that one already got its `null` and moved on.
  final Set<String> _notFound = {};

  /// Synchronous lookup, so a widget that mounts after another one already
  /// fetched this id can show it on the very first frame instead of waiting
  /// out another round trip through [resolve].
  Reel? cached(String reelId) => _resolved[reelId];

  /// Resolves one id. Never re-fetches an id already resolved or already
  /// known-missing, and never starts a second request for one already in
  /// flight. A fetch that fails resolves to null rather than throwing, so
  /// the caller can drop it exactly like the original "not in the library"
  /// behaviour did.
  Future<Reel?> resolve(String reelId) {
    final hit = _resolved[reelId];
    if (hit != null) return Future.value(hit);
    if (_notFound.contains(reelId)) return Future.value(null);
    return _inFlight.putIfAbsent(reelId, () => _fetchAndCache(reelId));
  }

  Future<Reel?> _fetchAndCache(String reelId) async {
    try {
      final reel = await _fetchReel(reelId);
      _resolved[reelId] = reel;
      return reel;
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) _notFound.add(reelId);
      return null;
    } finally {
      _inFlight.remove(reelId);
    }
  }
}
