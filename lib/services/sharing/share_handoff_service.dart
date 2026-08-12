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
    final prefs = await SharedPreferences.getInstance();
    final cleaned = token?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      await prefs.remove(_shareTokenKey);
    } else {
      await prefs.setString(_shareTokenKey, cleaned);
    }
    await _syncNative();
  }

  Future<void> syncAuthenticatedUser(String userId, String? accessToken) async {
    if (userId.trim().isEmpty) {
      await clear();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextBaseUrl = ApiConfig.baseUrl.trim();
    final currentBaseUrl = prefs.getString(_baseUrlKey)?.trim();
    await prefs.setString(_userIdKey, userId.trim());
    final cleanedAccessToken = accessToken?.trim();
    if (cleanedAccessToken == null || cleanedAccessToken.isEmpty) {
      await prefs.remove(_accessTokenKey);
    } else {
      await prefs.setString(_accessTokenKey, cleanedAccessToken);
    }
    if (currentBaseUrl != null &&
        currentBaseUrl.isNotEmpty &&
        currentBaseUrl != nextBaseUrl) {
      await prefs.remove(_shareTokenKey);
    }
    await prefs.setString(_baseUrlKey, nextBaseUrl);
    await _syncNative();
  }

  /// Mirrors the user's editable collections to native so the share sheet can
  /// offer them with no network call. A share extension has a tiny time budget
  /// and can be killed mid-request, so the picker reads this cached snapshot
  /// rather than hitting the API.
  ///
  /// Only id and name are stored — it is a picker, not a detail view.
  Future<void> syncCollections(List<CollectionSummary> collections) async {
    final editable = collections
        .where((c) => c.canEdit)
        .map((c) => {'id': c.id, 'name': c.name})
        .toList(growable: false);
    final encoded = editable.isEmpty ? '' : jsonEncode(editable);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (encoded.isEmpty) {
        await prefs.remove(_collectionsKey);
      } else {
        await prefs.setString(_collectionsKey, encoded);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_pushTokenKey);
    await prefs.remove(_pushPlatformKey);
    await prefs.remove(_shareTokenKey);
    if (!_supportsNativeHandoff) return;
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

  Future<void> _syncNative() async {
    if (!_supportsNativeHandoff) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _channel.invokeMethod<void>('sync', <String, String>{
        'shareToken': prefs.getString(_shareTokenKey) ?? '',
        'baseUrl': prefs.getString(_baseUrlKey) ?? '',
        'pushToken': prefs.getString(_pushTokenKey) ?? '',
        'pushPlatform': prefs.getString(_pushPlatformKey) ?? '',
        'collections': prefs.getString(_collectionsKey) ?? '',
      });
    } catch (e) {
      AppLogger.error('Share handoff native sync skipped: $e');
    }
  }
}
