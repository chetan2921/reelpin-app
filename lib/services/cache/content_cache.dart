import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/utils/app_logger.dart';

/// Cache slots written by [ApiClient] and read back on cold start.
class ContentCacheKeys {
  const ContentCacheKeys._();

  static const reelsFirstPage = 'reels_first_page';
  static const mapOverview = 'map_overview';
  static const discoverOverview = 'discover_overview';
  static const reelFilters = 'reel_filters';
  static const collections = 'collections';
  static const entitlements = 'entitlements';

  /// Saved-library payloads. These go stale together whenever the user adds or
  /// removes something, so they are invalidated as a group.
  static const contentKeys = <String>[
    reelsFirstPage,
    mapOverview,
    discoverOverview,
    reelFilters,
    collections,
  ];

  static const all = <String>[...contentKeys, entitlements];
}

/// Disk cache for the payloads the app needs on its very first frame.
///
/// Each slot stores the raw decoded API response, so hydration re-uses the same
/// `fromJson` factories as the network path and cannot drift from them. Every
/// entry is stamped with the owning user id and a write timestamp; reads reject
/// anything belonging to a different user or older than the slot's max age.
///
/// The cache is strictly best-effort: any failure degrades to a normal network
/// load rather than surfacing an error.
class ContentCache {
  ContentCache._({
    String? Function()? userIdProvider,
    Future<Directory> Function()? directoryLoader,
  }) : _userIdProvider = userIdProvider ?? _signedInUserId,
       _directoryLoader = directoryLoader ?? _createDirectory;

  static final ContentCache instance = ContentCache._();

  /// Builds an isolated cache over [directory] with a fixed user id.
  @visibleForTesting
  factory ContentCache.forTesting({
    required Directory directory,
    required String? Function() userIdProvider,
  }) {
    return ContentCache._(
      userIdProvider: userIdProvider,
      directoryLoader: () async {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      },
    );
  }

  static const _schemaVersion = 1;
  static const _directoryName = 'content_cache';
  static const _defaultMaxAge = Duration(days: 7);

  /// Access state is re-checked against the server on every launch, so a stale
  /// entitlement should never be trusted for long.
  static const _entitlementsMaxAge = Duration(hours: 24);

  final String? Function() _userIdProvider;
  final Future<Directory> Function() _directoryLoader;

  Future<Directory>? _directoryFuture;
  final Map<String, Future<void>> _pendingWrites = <String, Future<void>>{};
  bool _isDirectoryUnavailable = false;

  bool get _isSupported => !kIsWeb && !_isDirectoryUnavailable;

  String? get _currentUserId => _userIdProvider();

  static String? _signedInUserId() {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id.trim();
      if (userId == null || userId.isEmpty) return null;
      return userId;
    } catch (_) {
      return null;
    }
  }

  Duration _maxAgeFor(String key) => key == ContentCacheKeys.entitlements
      ? _entitlementsMaxAge
      : _defaultMaxAge;

  /// Returns the cached payload for [key], or null when there is nothing usable.
  Future<Map<String, dynamic>?> read(String key) async {
    if (!_isSupported) return null;

    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final file = await _fileFor(key);
      if (file == null || !await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['schema'] != _schemaVersion) {
        unawaited(invalidate(key));
        return null;
      }
      // A payload saved by a different account must never be shown.
      if (envelope['user_id'] != userId) return null;

      final savedAt = DateTime.tryParse(envelope['saved_at']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().toUtc().difference(savedAt.toUtc()) >
              _maxAgeFor(key)) {
        unawaited(invalidate(key));
        return null;
      }

      final payload = envelope['payload'];
      if (payload is! Map) return null;
      return Map<String, dynamic>.from(payload);
    } catch (e) {
      AppLogger.error('Content cache read skipped for $key: $e');
      return null;
    }
  }

  /// Stores [payload] for [key]. Writes for the same key are serialized so a
  /// slow write can never land on top of a newer one.
  Future<void> write(String key, Map<String, dynamic> payload) {
    if (!_isSupported) return Future<void>.value();

    final userId = _currentUserId;
    if (userId == null) return Future<void>.value();

    final previous = _pendingWrites[key] ?? Future<void>.value();
    final next = previous
        .then((_) => _write(key, userId: userId, payload: payload))
        .catchError((Object e) {
          AppLogger.error('Content cache write skipped for $key: $e');
        });
    _pendingWrites[key] = next;
    return next.whenComplete(() {
      if (identical(_pendingWrites[key], next)) {
        _pendingWrites.remove(key);
      }
    });
  }

  Future<void> _write(
    String key, {
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final file = await _fileFor(key);
    if (file == null) return;

    final envelope = jsonEncode(<String, dynamic>{
      'schema': _schemaVersion,
      'user_id': userId,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });

    // Write-then-rename so a crash mid-write cannot leave a truncated file that
    // would be read back as corrupt JSON.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(envelope, flush: true);
    await temporary.rename(file.path);
  }

  /// Drops a single slot.
  Future<void> invalidate(String key) async {
    if (!_isSupported) return;

    try {
      final file = await _fileFor(key);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.error('Content cache invalidate skipped for $key: $e');
    }
  }

  /// Drops every saved-library slot, leaving entitlements in place.
  ///
  /// Called whenever the library changes (a reel is saved or deleted, a map pin
  /// is added or removed) so a cold start after that change cannot show a
  /// snapshot taken before it.
  Future<void> invalidateContent() async {
    await Future.wait(ContentCacheKeys.contentKeys.map(invalidate));
  }

  /// Wipes everything. Used on sign-out and account deletion.
  Future<void> clear() async {
    if (!_isSupported) return;

    try {
      final directory = await _directory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      AppLogger.error('Content cache clear skipped: $e');
    } finally {
      _directoryFuture = null;
    }
  }

  Future<File?> _fileFor(String key) async {
    try {
      final directory = await _directory();
      return File('${directory.path}${Platform.pathSeparator}$key.json');
    } catch (e) {
      // No usable storage on this host (no platform binding, sandbox denial).
      // Latch it off rather than logging on every request for the rest of the
      // session — callers already fall back to the network.
      if (!_isDirectoryUnavailable) {
        _isDirectoryUnavailable = true;
        AppLogger.error('Content cache disabled, directory unavailable: $e');
      }
      return null;
    }
  }

  Future<Directory> _directory() {
    final existing = _directoryFuture;
    if (existing != null) return existing;

    final future = _directoryLoader();
    _directoryFuture = future;
    return future.catchError((Object e) {
      if (identical(_directoryFuture, future)) {
        _directoryFuture = null;
      }
      throw e;
    });
  }

  static Future<Directory> _createDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}$_directoryName',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
