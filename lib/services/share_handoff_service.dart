import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ShareHandoffService {
  ShareHandoffService._();

  static final ShareHandoffService instance = ShareHandoffService._();

  static const _userIdKey = 'share_handoff_user_id';
  static const _baseUrlKey = 'share_handoff_base_url';

  Future<void> syncAuthenticatedUser(String userId) async {
    if (userId.trim().isEmpty) {
      await clear();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId.trim());
    await prefs.setString(_baseUrlKey, ApiConfig.baseUrl.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_baseUrlKey);
  }
}
