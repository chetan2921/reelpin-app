import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/core/network/api_service.dart';
import 'package:reelpin/core/platform/device_metadata_service.dart';
import 'package:reelpin/core/platform/notification_service.dart';
import 'package:reelpin/features/sharing/services/push_registration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers startup and refreshed tokens with device metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final api = ApiService(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'access-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    final service = PushRegistrationService(
      notificationService: NotificationService.instance,
      sharingApi: api,
      deviceMetadataService: const _FakeDeviceMetadataService(),
    );

    await service.register(userId: 'user-1', candidateToken: 'startup-token');
    await service.register(userId: 'user-1', candidateToken: 'refresh-token');

    expect(requests, hasLength(2));
    expect(requests.first.headers['Authorization'], 'Bearer access-token');
    expect(jsonDecode(requests.first.body), {
      'token': 'startup-token',
      'platform': 'android',
      'app_version': '1.0.8',
      'app_build': '14',
      'timezone': 'Asia/Kolkata',
      'locale': 'en-IN',
    });
    expect(jsonDecode(requests.last.body)['token'], 'refresh-token');
  });

  test('unregisters the latest known token', () async {
    SharedPreferences.setMockInitialValues({});
    http.Request? deletion;
    final api = ApiService(
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'access-token',
      client: MockClient((request) async {
        if (request.method == 'DELETE') deletion = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    final service = PushRegistrationService(
      notificationService: NotificationService.instance,
      sharingApi: api,
      deviceMetadataService: const _FakeDeviceMetadataService(),
    );

    await service.register(userId: 'user-1', candidateToken: 'latest-token');
    await service.unregisterCurrentDevice();

    expect(deletion, isNotNull);
    expect(jsonDecode(deletion!.body), {'token': 'latest-token'});
  });
}

class _FakeDeviceMetadataService extends DeviceMetadataService {
  const _FakeDeviceMetadataService();

  @override
  Future<DeviceMetadata> load() async {
    return const DeviceMetadata(
      appVersion: '1.0.8',
      appBuild: '14',
      timezone: 'Asia/Kolkata',
      locale: 'en-IN',
    );
  }
}
