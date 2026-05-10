import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ShareHandoffService {
  ShareHandoffService._();

  static final ShareHandoffService instance = ShareHandoffService._();

  static const _userIdKey = 'share_handoff_user_id';
  static const _baseUrlKey = 'share_handoff_base_url';
  static const _pushTokenKey = 'share_handoff_push_token';
  static const _pushPlatformKey = 'share_handoff_push_platform';

  Future<void> syncAuthenticatedUser(String userId) async {
    if (userId.trim().isEmpty) {
      await clear();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId.trim());
    await prefs.setString(_baseUrlKey, ApiConfig.baseUrl.trim());
  }

  Future<void> syncPushToken({
    required String token,
    required String platform,
  }) async {
    final cleanedToken = token.trim();
    final cleanedPlatform = platform.trim().toLowerCase();
    if (cleanedToken.isEmpty || cleanedPlatform.isEmpty) {
      await clearPushToken();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pushTokenKey, cleanedToken);
    await prefs.setString(_pushPlatformKey, cleanedPlatform);
  }

  Future<void> clearPushToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pushTokenKey);
    await prefs.remove(_pushPlatformKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_pushTokenKey);
    await prefs.remove(_pushPlatformKey);
  }
}
