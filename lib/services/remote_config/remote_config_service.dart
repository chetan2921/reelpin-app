import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/data_models/app_config/remote_config.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Fetches the remote switches document and keeps the last good copy on disk.
///
/// Fails open: a missing URL, a timeout, a non-200 or a body that is not a
/// JSON object all come back as null, and the caller keeps whatever it already
/// had. Nothing here throws.
class RemoteConfigService {
  RemoteConfigService({
    required String url,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    this.refreshInterval = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : _url = url.trim(),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const _cachedDocumentKey = 'remote_config_document_v1';
  static const _fetchedAtKey = 'remote_config_fetched_at_v1';
  static const _shownAnnouncementsKey = 'remote_config_shown_announcements_v1';

  final String _url;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration timeout;
  final Duration refreshInterval;

  bool get isEnabled => _url.isNotEmpty;

  Future<RemoteConfig?> readCached() async {
    if (!isEnabled) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedDocumentKey);
      if (raw == null) return null;
      return _decode(raw);
    } catch (e) {
      AppLogger.error('Remote config cache read skipped: $e');
      return null;
    }
  }

  /// Null when the last successful fetch is under [refreshInterval] old, so
  /// launch and resume together cost at most one request an hour. Only a
  /// success is stamped: a failed attempt is retried at the next launch or
  /// resume rather than waiting out the hour.
  Future<RemoteConfig?> fetchIfDue() async {
    if (!isEnabled) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final fetchedAtMs = prefs.getInt(_fetchedAtKey);
      final now = _clock();
      if (fetchedAtMs != null) {
        final fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
        final age = now.difference(fetchedAt);
        if (!age.isNegative && age < refreshInterval) return null;
      }

      final response = await _client
          .get(Uri.parse(_url), headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        AppLogger.error(
          'Remote config fetch skipped: HTTP ${response.statusCode}',
        );
        return null;
      }

      final body = utf8.decode(response.bodyBytes);
      final config = _decode(body);
      await prefs.setString(_cachedDocumentKey, body);
      await prefs.setInt(_fetchedAtKey, now.millisecondsSinceEpoch);
      return config;
    } catch (e) {
      AppLogger.error('Remote config fetch skipped: $e');
      return null;
    }
  }

  Future<bool> wasAnnouncementShown(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getStringList(_shownAnnouncementsKey) ?? const [];
      return shown.contains(id);
    } catch (e) {
      AppLogger.error('Announcement history read skipped: $e');
      // Unreadable history cannot tell a seen announcement from a new one;
      // staying quiet is the miss nobody notices.
      return true;
    }
  }

  Future<void> markAnnouncementShown(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getStringList(_shownAnnouncementsKey) ?? <String>[];
      if (shown.contains(id)) return;
      await prefs.setStringList(_shownAnnouncementsKey, [...shown, id]);
    } catch (e) {
      AppLogger.error('Announcement history write skipped: $e');
    }
  }

  RemoteConfig _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('remote config is not a JSON object');
    }
    return RemoteConfig.fromJson(Map<String, dynamic>.from(decoded));
  }
}
