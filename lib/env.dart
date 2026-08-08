import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  /// The only two hosts the app talks to: release builds hit production, every
  /// other build hits the dev deployment. LAN and emulator hosts were removed —
  /// point a build at a local server with --dart-define=API_BASE_URL instead.
  static const String _productionBaseUrl = 'https://api.reelpin.in';
  static const String _devBaseUrl = 'https://api-dev.reelpin.in';

  /// API URL, overridable for local development with:
  /// `tool/reelpin_flutter.sh run --dart-define=API_BASE_URL=http://<ip>:8000`
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }
    return kReleaseMode ? _productionBaseUrl : _devBaseUrl;
  }
}

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
