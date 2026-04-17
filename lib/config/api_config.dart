import 'supabase_config.dart';

class ApiConfig {
  ApiConfig._();

  static const String _productionBaseUrl =
      'https://reelpin-api-production.up.railway.app/api/v1';
  static const String _defaultLanBaseUrl = 'http://192.168.1.4:8000/api/v1';
  static const String _legacyLanBaseUrl = 'http://192.168.1.2:8000/api/v1';
  static const String _olderLanBaseUrl = 'http://192.168.1.3:8000/api/v1';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';

  /// Production API URL, overridable for local development.
  static String get baseUrl {
    // Override with: flutter run --dart-define=API_BASE_URL=http://<ip>:8000/api/v1
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    final local = SupabaseConfig.localValue('API_BASE_URL');
    return _firstNonEmpty(fromEnv, local, fallback: _productionBaseUrl);
  }

  /// Additional URLs to auto-try when the primary host is unreachable.
  static List<String> get fallbackBaseUrls {
    final primary = baseUrl;
    if (!_isLocalDevUrl(primary)) {
      return const [];
    }

    final candidates = <String>[
      _defaultLanBaseUrl,
      _legacyLanBaseUrl,
      _olderLanBaseUrl,
      _androidEmulatorBaseUrl,
    ];

    final fallbacks = <String>[];
    for (final candidate in candidates) {
      if (candidate == primary) continue;
      if (!fallbacks.contains(candidate)) {
        fallbacks.add(candidate);
      }
    }
    return fallbacks;
  }

  static String _firstNonEmpty(
    String? primary,
    String? secondary, {
    required String fallback,
  }) {
    if (primary != null && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    if (secondary != null && secondary.trim().isNotEmpty) {
      return secondary.trim();
    }
    return fallback;
  }

  static bool _isLocalDevUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    final host = (uri?.host ?? '').trim().toLowerCase();
    if (host.isEmpty) return false;
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.');
  }
}
