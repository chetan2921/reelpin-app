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

/// Linkrunner drives deferred deep links: a share link opens the app when it is
/// installed and the store otherwise, then routes to the right collection once
/// the install completes.
///
/// Every value is build-time only. With no token the SDK is never initialised
/// and link handling falls back to parsing the incoming URL directly, which is
/// exactly how the app behaved before Linkrunner was added.
class LinkrunnerConfig {
  LinkrunnerConfig._();

  static const String _token = String.fromEnvironment('LINKRUNNER_TOKEN');
  static const String _secretKey = String.fromEnvironment(
    'LINKRUNNER_SECRET_KEY',
  );
  static const String _keyId = String.fromEnvironment('LINKRUNNER_KEY_ID');

  static String get token => _token.trim();

  /// Optional — only needed when the project enforces signed attribution.
  static String? get secretKey =>
      _secretKey.trim().isEmpty ? null : _secretKey.trim();

  static String? get keyId => _keyId.trim().isEmpty ? null : _keyId.trim();

  static bool get isConfigured => token.isNotEmpty;
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
