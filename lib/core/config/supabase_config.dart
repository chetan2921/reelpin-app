import 'package:flutter/foundation.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String _urlFromEnv = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKeyFromEnv = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static Future<void> loadLocalConfig() async {}

  static String get url => _urlFromEnv.trim();

  static String get anonKey => _anonKeyFromEnv.trim();

  // These schemes must match AndroidManifest.xml and Info.plist.
  static String get redirectScheme => _defaultRedirectScheme();

  static const String redirectHost = 'login-callback';

  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static String get redirectUrl => '$redirectScheme://$redirectHost';

  static String _defaultRedirectScheme() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'com.chetanjain.reelpin';
    }
    return 'com.chetan.reelpin';
  }
}
