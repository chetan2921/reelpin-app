import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/utils/app_logger.dart';

/// Remembers the share URL a collection link was last issued under.
///
/// The backend stores only the SHA-256 hash of a share token, so an enabled
/// link can never be read back from the server — `POST .../link` mints a fresh
/// token and invalidates the previous one. Without this cache the owner sees
/// "link is on" with no URL, and the only way to get one is to regenerate,
/// silently breaking every link already sent out.
///
/// So the device that created the link keeps a copy. A cache miss (new device,
/// reinstall, cleared storage) is not an error — it just means the sheet offers
/// to generate a link instead of showing one.
class CollectionLinkCache {
  CollectionLinkCache._();

  static final CollectionLinkCache instance = CollectionLinkCache._();

  static const _keyPrefix = 'collection_share_link_v1_';

  String _keyFor(String collectionId) => '$_keyPrefix${collectionId.trim()}';

  Future<String?> read(String collectionId) async {
    if (collectionId.trim().isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_keyFor(collectionId))?.trim();
      return (url == null || url.isEmpty) ? null : url;
    } catch (e) {
      AppLogger.error('Collection link cache read skipped: $e');
      return null;
    }
  }

  Future<void> write(String collectionId, String url) async {
    if (collectionId.trim().isEmpty || url.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFor(collectionId), url.trim());
    } catch (e) {
      AppLogger.error('Collection link cache write skipped: $e');
    }
  }

  /// Called when the link is turned off or the collection is gone — a stale URL
  /// would otherwise be offered for copying long after it stopped resolving.
  Future<void> clear(String collectionId) async {
    if (collectionId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(collectionId));
    } catch (e) {
      AppLogger.error('Collection link cache clear skipped: $e');
    }
  }
}
