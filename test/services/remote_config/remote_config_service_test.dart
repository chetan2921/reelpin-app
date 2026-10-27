import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/services/remote_config/remote_config_service.dart';

const _url = 'https://config.example.com/reelpin.json';

final _document = jsonEncode({
  'update_required': {
    'enabled': true,
    'min_build': {'ios': 30, 'android': 24},
    'hard': false,
  },
  'paywall_visible': true,
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('an empty URL makes no request and returns nothing', () async {
    var requests = 0;
    final service = RemoteConfigService(
      url: '  ',
      client: MockClient((_) async {
        requests += 1;
        return http.Response(_document, 200);
      }),
    );

    expect(service.isEnabled, isFalse);
    expect(await service.fetchIfDue(), isNull);
    expect(await service.readCached(), isNull);
    expect(requests, 0);
  });

  test('a successful fetch is returned and cached', () async {
    late http.Request seen;
    final service = RemoteConfigService(
      url: _url,
      client: MockClient((request) async {
        seen = request;
        return http.Response(_document, 200);
      }),
    );

    final fetched = await service.fetchIfDue();

    expect(seen.method, 'GET');
    expect(seen.url.toString(), _url);
    expect(fetched?.paywallVisible, isTrue);
    expect(fetched?.updateRequired.minBuildAndroid, 24);
    expect((await service.readCached())?.paywallVisible, isTrue);
  });

  test('refetches only once the last fetch is an hour old', () async {
    var now = DateTime(2026, 10, 20, 9);
    var requests = 0;
    final service = RemoteConfigService(
      url: _url,
      clock: () => now,
      client: MockClient((_) async {
        requests += 1;
        return http.Response(_document, 200);
      }),
    );

    await service.fetchIfDue();
    now = now.add(const Duration(minutes: 59));
    expect(await service.fetchIfDue(), isNull);
    expect(requests, 1);

    now = now.add(const Duration(minutes: 1));
    expect(await service.fetchIfDue(), isNotNull);
    expect(requests, 2);
  });

  test('a failed fetch is retried without waiting out the hour', () async {
    var requests = 0;
    final service = RemoteConfigService(
      url: _url,
      client: MockClient((_) async {
        requests += 1;
        return requests == 1
            ? http.Response('nope', 503)
            : http.Response(_document, 200);
      }),
    );

    expect(await service.fetchIfDue(), isNull);
    expect(await service.fetchIfDue(), isNotNull);
    expect(requests, 2);
  });

  group('fails open', () {
    Future<void> expectFailureKeepsCache(http.Client failing) async {
      SharedPreferences.setMockInitialValues({
        'remote_config_document_v1': _document,
      });
      final service = RemoteConfigService(
        url: _url,
        client: failing,
        timeout: const Duration(milliseconds: 50),
      );

      expect(await service.fetchIfDue(), isNull);
      expect((await service.readCached())?.paywallVisible, isTrue);
    }

    test('on a server error', () async {
      await expectFailureKeepsCache(
        MockClient((_) async => http.Response('down', 500)),
      );
    });

    test('on a network error', () async {
      await expectFailureKeepsCache(
        MockClient((_) async => throw http.ClientException('offline')),
      );
    });

    test('on a body that is not a JSON object', () async {
      await expectFailureKeepsCache(
        MockClient((_) async => http.Response('[1, 2]', 200)),
      );
    });

    test('on a timeout', () async {
      await expectFailureKeepsCache(
        MockClient((_) => Completer<http.Response>().future),
      );
    });

    test('on a corrupt cache entry', () async {
      SharedPreferences.setMockInitialValues({
        'remote_config_document_v1': '{not json',
      });
      final service = RemoteConfigService(url: _url);

      expect(await service.readCached(), isNull);
    });
  });

  test('remembers shown announcement ids across instances', () async {
    final first = RemoteConfigService(url: _url);
    expect(await first.wasAnnouncementShown('maps-v2'), isFalse);

    await first.markAnnouncementShown('maps-v2');
    await first.markAnnouncementShown('maps-v2');

    final second = RemoteConfigService(url: _url);
    expect(await second.wasAnnouncementShown('maps-v2'), isTrue);
    expect(await second.wasAnnouncementShown('chat-v1'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('remote_config_shown_announcements_v1'), [
      'maps-v2',
    ]);
  });
}
