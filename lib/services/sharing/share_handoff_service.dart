import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';

class ShareHandoffService {
  ShareHandoffService._();

  static final ShareHandoffService instance = ShareHandoffService._();

  // Bridge to the native-owned SharedPreferences read by ShareEnqueueService.
  // The Flutter shared_preferences plugin stores values in a DataStore that
  // native (background) code cannot read, so the handoff values are mirrored
  // into a native store through this channel.
  static const _channel = MethodChannel('com.chetanjain.reelpin/share_handoff');

  static const _userIdKey = 'share_handoff_user_id';
  static const _accessTokenKey = 'share_handoff_access_token';
  static const _baseUrlKey = 'share_handoff_base_url';
  static const _pushTokenKey = 'share_handoff_push_token';
  static const _pushPlatformKey = 'share_handoff_push_platform';
  static const _shareTokenKey = 'share_handoff_share_token';
  static const _collectionsKey = 'share_handoff_collections';
  static const _collectionsDirKey = 'share_handoff_collections_dir';
  static const _collectionPickerKey = 'share_handoff_collection_picker';

  int _sessionGeneration = 0;
  int _collectionsGeneration = 0;

  bool get _supportsNativeHandoff =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<String?> getShareToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_shareTokenKey)?.trim();
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> setShareToken(String? token) async {
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    final cleaned = token?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      await prefs.remove(_shareTokenKey);
    } else {
      await prefs.setString(_shareTokenKey, cleaned);
    }
    await _syncNative();
  }

  Future<void> syncAuthenticatedUser(String userId, String? accessToken) async {
    final nextUserId = userId.trim();
    if (nextUserId.isEmpty) {
      await clear();
      return;
    }

    final generation = ++_sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    final nextBaseUrl = ApiConfig.baseUrl.trim();
    final currentBaseUrl = prefs.getString(_baseUrlKey)?.trim();
    final userChanged = prefs.getString(_userIdKey) != nextUserId;
    if (userChanged) {
      _collectionsGeneration += 1;
      await prefs.remove(_collectionsKey);
      if (generation != _sessionGeneration) return;
      await prefs.remove(_collectionsDirKey);
      if (generation != _sessionGeneration) return;
    }
    if (userChanged ||
        (currentBaseUrl != null &&
            currentBaseUrl.isNotEmpty &&
            currentBaseUrl != nextBaseUrl)) {
      await prefs.remove(_shareTokenKey);
      if (generation != _sessionGeneration) return;
    }
    await prefs.setString(_userIdKey, nextUserId);
    if (generation != _sessionGeneration) return;
    final cleanedAccessToken = accessToken?.trim();
    if (cleanedAccessToken == null || cleanedAccessToken.isEmpty) {
      await prefs.remove(_accessTokenKey);
    } else {
      await prefs.setString(_accessTokenKey, cleanedAccessToken);
    }
    if (generation != _sessionGeneration) return;
    await prefs.setString(_baseUrlKey, nextBaseUrl);
    if (generation != _sessionGeneration) return;
    await _syncNative();
  }

  /// Whether a share into ReelPin stops to offer collections. On by default:
  /// filing at share time is the point of the picker. Turning it off restores
  /// the one-tap save for people who never file.
  Future<bool> isCollectionPickerEnabled() async {
    // Best-effort like the rest of this service: an unreadable store means the
    // picker stays on, which is the behaviour the user did not ask to change.
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_collectionPickerKey) ?? true;
    } catch (e) {
      AppLogger.error('Share collection picker preference read skipped: $e');
      return true;
    }
  }

  /// Persists the choice and re-syncs, so the next share honours it without
  /// waiting for a collections reload.
  Future<void> setCollectionPickerEnabled(
    bool enabled,
    List<CollectionSummary> collections, {
    Future<Map<String, String>> Function({
      required String directory,
      required List<CollectionSummary> collections,
    })?
    renderTiles,
  }) async {
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_collectionPickerKey, enabled);
    if (generation != _sessionGeneration) return;
    await syncCollections(collections, renderTiles: renderTiles);
  }

  /// Mirrors the user's editable collections to native so the share sheet can
  /// offer them with no network call. A share extension has a tiny time budget
  /// and can be killed mid-request, so the picker reads this cached snapshot
  /// rather than hitting the API.
  ///
  /// Only id and name are stored — it is a picker, not a detail view.
  ///
  /// With the picker turned off the snapshot is cleared rather than skipped:
  /// an empty list is already how both platforms mean "save without asking",
  /// so the preference needs no native code of its own.
  /// [renderTiles] draws each collection's artwork into the directory it is
  /// given and returns the file name per id. Injected because drawing a widget
  /// is a component's job and this layer may not reach into one; a null
  /// renderer simply syncs names without artwork.
  Future<void> syncCollections(
    List<CollectionSummary> collections, {
    Future<Map<String, String>> Function({
      required String directory,
      required List<CollectionSummary> collections,
    })?
    renderTiles,
  }) async {
    final generation = ++_collectionsGeneration;
    final sessionGeneration = _sessionGeneration;
    final pickerEnabled = await isCollectionPickerEnabled();
    if (generation != _collectionsGeneration ||
        sessionGeneration != _sessionGeneration) {
      return;
    }
    final editable = pickerEnabled
        ? collections.where((c) => c.canEdit).toList(growable: false)
        : const <CollectionSummary>[];

    // Render the real folder tile to PNG so the native sheets show the same
    // artwork as the SAVED tab rather than a native approximation.
    var artwork = <String, String>{};
    String? assetsDir;
    if (editable.isNotEmpty && renderTiles != null) {
      assetsDir = await _shareAssetsDirectory();
      if (generation != _collectionsGeneration ||
          sessionGeneration != _sessionGeneration) {
        return;
      }
      if (assetsDir != null) {
        artwork = await renderTiles(
          directory: assetsDir,
          collections: editable,
        );
      }
    }

    final payload = editable
        .map(
          (c) => {
            'id': c.id,
            'name': c.name,
            if (artwork[c.id] != null) 'image': artwork[c.id],
          },
        )
        .toList(growable: false);
    final encoded = payload.isEmpty ? '' : jsonEncode(payload);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _collectionsGeneration ||
          sessionGeneration != _sessionGeneration) {
        return;
      }
      if (encoded.isEmpty) {
        await prefs.remove(_collectionsKey);
        if (generation != _collectionsGeneration ||
            sessionGeneration != _sessionGeneration) {
          return;
        }
        await prefs.remove(_collectionsDirKey);
      } else {
        await prefs.setString(_collectionsKey, encoded);
        if (generation != _collectionsGeneration ||
            sessionGeneration != _sessionGeneration) {
          return;
        }
        if (assetsDir != null) {
          await prefs.setString(_collectionsDirKey, assetsDir);
        }
      }
      if (generation != _collectionsGeneration ||
          sessionGeneration != _sessionGeneration) {
        return;
      }
      await _syncNative();
    } catch (e) {
      // The picker degrades to "save without a collection", which is the
      // pre-existing behaviour. Never worth surfacing.
      AppLogger.error('Collection share-target sync skipped: $e');
    }
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
    await _syncNative();
  }

  Future<void> clearPushToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pushTokenKey);
    await prefs.remove(_pushPlatformKey);
    await _syncNative();
  }

  Future<void> clear() async {
    final generation = ++_sessionGeneration;
    _collectionsGeneration += 1;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _userIdKey,
      _accessTokenKey,
      _baseUrlKey,
      _pushTokenKey,
      _pushPlatformKey,
      _shareTokenKey,
      _collectionsKey,
      _collectionsDirKey,
    ]) {
      if (generation != _sessionGeneration) return;
      await prefs.remove(key);
    }
    if (generation != _sessionGeneration || !_supportsNativeHandoff) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (e) {
      AppLogger.error('Share handoff native clear skipped: $e');
    }
  }

  /// Returns the JSON-encoded list of pending shared URLs captured natively by
  /// the share receiver, clearing them on the native side.
  Future<String?> drainPendingShares() async {
    if (!_supportsNativeHandoff) return null;
    try {
      return await _channel.invokeMethod<String>('drainPending');
    } catch (e) {
      AppLogger.error('Pending share drain (native) skipped: $e');
      return null;
    }
  }

  /// Where native wants rendered artwork written. On iOS this must be the App
  /// Group container — the Share Extension is a separate sandbox and cannot
  /// read the app's own documents directory.
  Future<String?> _shareAssetsDirectory() async {
    if (!_supportsNativeHandoff) return null;
    try {
      final dir = await _channel.invokeMethod<String>('shareAssetsDir');
      final cleaned = dir?.trim();
      return (cleaned == null || cleaned.isEmpty) ? null : cleaned;
    } catch (e) {
      AppLogger.error('Share assets dir lookup skipped: $e');
      return null;
    }
  }

  Future<void> _syncNative() async {
    if (!_supportsNativeHandoff) return;
    final generation = _sessionGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _sessionGeneration) return;
      await _channel.invokeMethod<void>('sync', <String, String>{
        'shareToken': prefs.getString(_shareTokenKey) ?? '',
        'baseUrl': prefs.getString(_baseUrlKey) ?? '',
        'pushToken': prefs.getString(_pushTokenKey) ?? '',
        'pushPlatform': prefs.getString(_pushPlatformKey) ?? '',
        'collections': prefs.getString(_collectionsKey) ?? '',
        'collectionsDir': prefs.getString(_collectionsDirKey) ?? '',
      });
    } catch (e) {
      AppLogger.error('Share handoff native sync skipped: $e');
    }
  }
}
