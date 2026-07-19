import 'package:flutter/foundation.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String _urlFromEnv = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKeyFromEnv = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _redirectSchemeFromEnv = String.fromEnvironment(
    'SUPABASE_REDIRECT_SCHEME',
  );
  static const String _redirectHostFromEnv = String.fromEnvironment(
    'SUPABASE_REDIRECT_HOST',
    defaultValue: 'login-callback',
  );

  static Future<void> loadLocalConfig() async {}

  static String get url => _urlFromEnv.trim();

  static String get anonKey => _anonKeyFromEnv.trim();

  static String get redirectScheme => _firstNonEmpty(
    _redirectSchemeFromEnv,
    null,
    fallback: _defaultRedirectScheme(),
  );

  static String get redirectHost =>
      _firstNonEmpty(_redirectHostFromEnv, null, fallback: 'login-callback');

  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static String get redirectUrl => '$redirectScheme://$redirectHost';

  static String _defaultRedirectScheme() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'com.chetanjain.reelpin';
    }
    return 'com.chetan.reelpin';
  }

  static String _firstNonEmpty(
    String? primary,
    String? secondary, {
    String fallback = '',
  }) {
    if (primary != null && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    if (secondary != null && secondary.trim().isNotEmpty) {
      return secondary.trim();
    }
    return fallback;
  }
}
