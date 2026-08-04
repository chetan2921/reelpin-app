import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/utils/app_logger.dart';

/// Tracks whether a signed-in user has already been walked through the
/// "how to save a reel" guide. The flag is keyed per user id so a second
/// account signing in on the same device still gets the walkthrough.
class HowToGuideService {
  HowToGuideService._();

  static final HowToGuideService instance = HowToGuideService._();

  static const _keyPrefix = 'how_to_guide_seen_v1_';

  String _keyFor(String userId) => '$_keyPrefix${userId.trim()}';

  Future<bool> hasSeenGuide(String userId) async {
    if (userId.trim().isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFor(userId)) ?? false;
    } catch (e) {
      AppLogger.error('How-to guide flag read skipped: $e');
      // Treat an unreadable flag as "already seen" so a storage failure never
      // pins the guide open on every launch.
      return true;
    }
  }

  Future<void> markGuideSeen(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFor(userId), true);
    } catch (e) {
      AppLogger.error('How-to guide flag write skipped: $e');
    }
  }
}
