import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static Map<String, String> _localValues = const {};

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

  static Future<void> loadLocalConfig() async {
    try {
      final raw = await rootBundle.loadString('assets/config/local.env');
      _localValues = _parseEnv(raw);
    } catch (_) {
      _localValues = const {};
    }
  }

  static String get url => _firstNonEmpty(
    _urlFromEnv,
    _localValues['SUPABASE_URL'],
  );

  static String get anonKey => _firstNonEmpty(
    _anonKeyFromEnv,
    _localValues['SUPABASE_ANON_KEY'],
  );

  static String get redirectScheme => _firstNonEmpty(
    _redirectSchemeFromEnv,
    _localValues['SUPABASE_REDIRECT_SCHEME'],
    fallback: _defaultRedirectScheme(),
  );

  static String get redirectHost => _firstNonEmpty(
    _redirectHostFromEnv,
    _localValues['SUPABASE_REDIRECT_HOST'],
    fallback: 'login-callback',
  );

  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static String get redirectUrl => '$redirectScheme://$redirectHost';

  static String? localValue(String key) => _localValues[key];

  static String _defaultRedirectScheme() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'com.chetanjain.reelpin';
    }
    return 'com.chetan.reelpin';
  }

  static Map<String, String> _parseEnv(String raw) {
    final values = <String, String>{};

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final separator = trimmed.indexOf('=');
      if (separator <= 0) {
        continue;
      }

      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      values[key] = value;
    }

    return values;
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
