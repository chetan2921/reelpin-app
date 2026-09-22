import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/utils/app_logger.dart';

/// Tracks whether the "how to save a reel" walkthrough is still owed.
///
/// It is armed when onboarding finishes and consumed the first time the shell
/// can show it. Updating the app never arms it, and neither does a reinstall
/// of an account that already holds reels — the flag says the *install* is
/// new, which is not the same as the user being new. The walkthrough stays
/// reachable from the empty state and from Profile either way.
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
  ///
  /// [hasExistingSaves] answers whether the account already holds reels.
  /// Reinstalling runs onboarding again, which arms the flag for an account of
  /// any age, so the flag alone cannot tell a new user from a returning one.
  /// It is only consulted once the flag is set, so the usual launch does not
  /// pay for it. The flag is spent either way: a user who is past needing the
  /// walkthrough should not meet it on the launch after, either.
  Future<bool> takePendingGuide({
    required Future<bool> Function() hasExistingSaves,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_pendingKey) ?? false)) return false;
      await prefs.remove(_pendingKey);
      return !await hasExistingSaves();
    } catch (e) {
      AppLogger.error('How-to guide flag read skipped: $e');
      // Neither an unreadable flag nor an uncountable library can tell a new
      // user from a returning one. Staying quiet is the safe half: the empty
      // state still offers the guide, where showing it to someone with a full
      // library is the miss that gets noticed.
      return false;
    }
  }
}
