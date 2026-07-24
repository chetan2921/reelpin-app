import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:reelpin/core/platform/app_update_service.dart';

void main() {
  group('iOS update check', () {
    test('requires an update when the App Store version is newer', () async {
      final service = AppUpdateService(
        targetPlatform: TargetPlatform.iOS,
        installedVersionLoader: () async => '1.0.10',
        client: MockClient((request) async {
          expect(request.url.host, 'itunes.apple.com');
          expect(request.url.queryParameters['id'], '6777110022');
          return http.Response(
            '{"resultCount":1,"results":[{"version":"1.0.11"}]}',
            200,
          );
        }),
      );

      final update = await service.checkForRequiredUpdate();

      expect(update, isNotNull);
      expect(update!.platform, AppUpdatePlatform.ios);
      expect(update.installedVersion, '1.0.10');
      expect(update.latestVersion, '1.0.11');
      expect(update.storeUri.host, 'apps.apple.com');
    });

    test('allows the current App Store version', () async {
      final service = AppUpdateService(
        targetPlatform: TargetPlatform.iOS,
        installedVersionLoader: () async => '1.0.10',
        client: MockClient(
          (_) async => http.Response(
            '{"resultCount":1,"results":[{"version":"1.0.10"}]}',
            200,
          ),
        ),
      );

      expect(await service.checkForRequiredUpdate(), isNull);
    });

    test('does not block when the App Store response is unavailable', () async {
      final service = AppUpdateService(
        targetPlatform: TargetPlatform.iOS,
        installedVersionLoader: () async => '1.0.10',
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );

      expect(await service.checkForRequiredUpdate(), isNull);
    });
  });

  test('Android update uses the immediate Play update flow', () async {
    var immediateUpdateCalls = 0;
    var storeLaunchCalls = 0;
    final service = AppUpdateService(
      targetPlatform: TargetPlatform.android,
      androidUpdateChecker: () async => _androidUpdateInfo(
        availability: UpdateAvailability.updateAvailable,
        immediateUpdateAllowed: true,
      ),
      immediateUpdatePerformer: () async {
        immediateUpdateCalls += 1;
        return AppUpdateResult.success;
      },
      storeLauncher: (_) async {
        storeLaunchCalls += 1;
        return true;
      },
    );

    final update = await service.checkForRequiredUpdate();

    expect(update, isNotNull);
    expect(update!.platform, AppUpdatePlatform.android);
    expect(update.immediateUpdateAllowed, isTrue);
    expect(await service.startUpdate(update), isTrue);
    expect(immediateUpdateCalls, 1);
    expect(storeLaunchCalls, 0);
  });

  test('Android falls back to Play when an immediate update fails', () async {
    Uri? openedUri;
    final service = AppUpdateService(
      targetPlatform: TargetPlatform.android,
      immediateUpdatePerformer: () async => AppUpdateResult.inAppUpdateFailed,
      storeLauncher: (uri) async {
        openedUri = uri;
        return true;
      },
    );
    final update = RequiredAppUpdate(
      platform: AppUpdatePlatform.android,
      storeUri: Uri.parse(
        'https://play.google.com/store/apps/details?id=com.chetanjain.reelpin',
      ),
      immediateUpdateAllowed: true,
    );

    expect(await service.startUpdate(update), isTrue);
    expect(openedUri, update.storeUri);
  });

  group('store version comparison', () {
    test('compares each numeric component', () {
      expect(isStoreVersionNewer('1.0.11', '1.0.10'), isTrue);
      expect(isStoreVersionNewer('2.0', '1.99.99'), isTrue);
      expect(isStoreVersionNewer('1.0.10', '1.0.10'), isFalse);
      expect(isStoreVersionNewer('1.0', '1.0.0'), isFalse);
      expect(isStoreVersionNewer('1.0.9', '1.0.10'), isFalse);
    });

    test('does not force an update for invalid versions', () {
      expect(isStoreVersionNewer('unknown', '1.0.10'), isFalse);
      expect(isStoreVersionNewer('1.0.11', 'unknown'), isFalse);
    });
  });
}

AppUpdateInfo _androidUpdateInfo({
  required UpdateAvailability availability,
  required bool immediateUpdateAllowed,
}) {
  return AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: immediateUpdateAllowed,
    immediateAllowedPreconditions: null,
    flexibleUpdateAllowed: false,
    flexibleAllowedPreconditions: null,
    availableVersionCode: 17,
    installStatus: InstallStatus.unknown,
    packageName: 'com.chetanjain.reelpin',
    clientVersionStalenessDays: 0,
    updatePriority: 5,
  );
}
