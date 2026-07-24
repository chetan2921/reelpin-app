import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reelpin/core/logging/app_logger.dart';
import 'package:reelpin/core/platform/device_metadata_service.dart';

typedef InstalledVersionLoader = Future<String> Function();
typedef AndroidUpdateChecker = Future<AppUpdateInfo> Function();
typedef ImmediateUpdatePerformer = Future<AppUpdateResult> Function();
typedef StoreLauncher = Future<bool> Function(Uri uri);

enum AppUpdatePlatform { android, ios }

class RequiredAppUpdate {
  const RequiredAppUpdate({
    required this.platform,
    required this.storeUri,
    this.installedVersion,
    this.latestVersion,
    this.immediateUpdateAllowed = false,
  });

  final AppUpdatePlatform platform;
  final Uri storeUri;
  final String? installedVersion;
  final String? latestVersion;
  final bool immediateUpdateAllowed;
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    TargetPlatform? targetPlatform,
    InstalledVersionLoader? installedVersionLoader,
    AndroidUpdateChecker? androidUpdateChecker,
    ImmediateUpdatePerformer? immediateUpdatePerformer,
    StoreLauncher? storeLauncher,
  }) : _client = client ?? http.Client(),
       _targetPlatform = targetPlatform ?? defaultTargetPlatform,
       _installedVersionLoader =
           installedVersionLoader ??
           (() async =>
               (await const DeviceMetadataService().load()).appVersion),
       _androidUpdateChecker =
           androidUpdateChecker ?? InAppUpdate.checkForUpdate,
       _immediateUpdatePerformer =
           immediateUpdatePerformer ?? InAppUpdate.performImmediateUpdate,
       _storeLauncher = storeLauncher ?? _launchExternalStore;

  static final Uri _appStoreLookupUri = Uri.https(
    'itunes.apple.com',
    '/lookup',
    const {'id': '6777110022'},
  );
  static final Uri _appStoreUri = Uri.parse(
    'https://apps.apple.com/us/app/reelpin/id6777110022',
  );
  static final Uri _playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.chetanjain.reelpin',
  );
  static const Duration _lookupTimeout = Duration(seconds: 5);

  final http.Client _client;
  final TargetPlatform _targetPlatform;
  final InstalledVersionLoader _installedVersionLoader;
  final AndroidUpdateChecker _androidUpdateChecker;
  final ImmediateUpdatePerformer _immediateUpdatePerformer;
  final StoreLauncher _storeLauncher;

  Future<RequiredAppUpdate?> checkForRequiredUpdate() async {
    if (kIsWeb) return null;

    return switch (_targetPlatform) {
      TargetPlatform.android => _checkAndroidUpdate(),
      TargetPlatform.iOS => _checkIosUpdate(),
      _ => Future<RequiredAppUpdate?>.value(),
    };
  }

  Future<bool> startUpdate(RequiredAppUpdate update) async {
    if (update.platform == AppUpdatePlatform.android &&
        update.immediateUpdateAllowed) {
      try {
        final result = await _immediateUpdatePerformer();
        if (result == AppUpdateResult.success) return true;
        if (result == AppUpdateResult.userDeniedUpdate) return false;
      } catch (e) {
        AppLogger.error('Immediate Android update failed: $e');
      }
    }

    try {
      return await _storeLauncher(update.storeUri);
    } catch (e) {
      AppLogger.error('App store launch failed: $e');
      return false;
    }
  }

  Future<RequiredAppUpdate?> _checkAndroidUpdate() async {
    try {
      final updateInfo = await _androidUpdateChecker().timeout(_lookupTimeout);
      final availability = updateInfo.updateAvailability;
      final updateRequired =
          availability == UpdateAvailability.updateAvailable ||
          availability == UpdateAvailability.developerTriggeredUpdateInProgress;
      if (!updateRequired) return null;

      return RequiredAppUpdate(
        platform: AppUpdatePlatform.android,
        storeUri: _playStoreUri,
        immediateUpdateAllowed:
            updateInfo.immediateUpdateAllowed ||
            availability ==
                UpdateAvailability.developerTriggeredUpdateInProgress,
      );
    } catch (e) {
      AppLogger.error('Android update check skipped: $e');
      return null;
    }
  }

  Future<RequiredAppUpdate?> _checkIosUpdate() async {
    try {
      final installedVersion = await _installedVersionLoader().timeout(
        _lookupTimeout,
      );
      final response = await _client
          .get(_appStoreLookupUri)
          .timeout(_lookupTimeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final results = body['results'];
      if (results is! List || results.isEmpty) return null;
      final listing = results.first;
      if (listing is! Map<String, dynamic>) return null;
      final latestVersion = listing['version']?.toString().trim();
      if (latestVersion == null ||
          !isStoreVersionNewer(latestVersion, installedVersion)) {
        return null;
      }

      return RequiredAppUpdate(
        platform: AppUpdatePlatform.ios,
        storeUri: _appStoreUri,
        installedVersion: installedVersion,
        latestVersion: latestVersion,
      );
    } catch (e) {
      AppLogger.error('iOS update check skipped: $e');
      return null;
    }
  }

  static Future<bool> _launchExternalStore(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

bool isStoreVersionNewer(String storeVersion, String installedVersion) {
  final storeParts = _versionParts(storeVersion);
  final installedParts = _versionParts(installedVersion);
  if (storeParts == null || installedParts == null) return false;

  final partCount = storeParts.length > installedParts.length
      ? storeParts.length
      : installedParts.length;
  for (var index = 0; index < partCount; index++) {
    final storePart = index < storeParts.length ? storeParts[index] : 0;
    final installedPart = index < installedParts.length
        ? installedParts[index]
        : 0;
    if (storePart != installedPart) return storePart > installedPart;
  }
  return false;
}

List<int>? _versionParts(String version) {
  final normalized = version.trim().split('+').first.split('-').first;
  if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(normalized)) return null;
  return normalized.split('.').map(int.parse).toList(growable: false);
}
