import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/utils/app_logger.dart';

/// Tracks whether the "how to save a reel" walkthrough is still owed.
///
/// It is armed when onboarding finishes, which only happens on a fresh
/// install, and consumed the first time the shell can show it. Updating the
/// app never arms it, so a user who already has reels saved goes straight to
/// their home screen; the walkthrough stays reachable from the empty state and
/// from Profile.
class HowToGuideService {
  HowToGuideService._();

  static final HowToGuideService instance = HowToGuideService._();

  static const _pendingKey = 'how_to_guide_pending_v1';

  Future<void> markGuidePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, true);
    } catch (e) {
      AppLogger.error('How-to guide flag write skipped: $e');
    }
  }

  /// Reads the flag and clears it in the same breath, so a walkthrough that
  /// gets interrupted — backgrounded, or the app killed part-way — does not
  /// come back on the next launch.
  Future<bool> takePendingGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_pendingKey) ?? false)) return false;
      await prefs.remove(_pendingKey);
      return true;
    } catch (e) {
      AppLogger.error('How-to guide flag read skipped: $e');
      // An unreadable flag cannot tell a new install from an old one. Staying
      // quiet is the safe half: the empty state still offers the guide.
      return false;
    }
  }
}
