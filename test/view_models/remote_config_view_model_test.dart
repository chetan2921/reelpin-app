import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/services/remote_config/remote_config_service.dart';
import 'package:reelpin/view_models/remote_config_view_model.dart';

const _url = 'https://config.example.com/reelpin.json';

Map<String, dynamic> _update({required bool hard, int android = 24}) => {
  'enabled': true,
  'min_build': {'ios': 30, 'android': android},
  'hard': hard,
};

const _announcement = {
  'enabled': true,
  'id': 'maps-v2',
  'title': 'NEW MAP',
  'body': 'Pins cluster now.',
  'show_once': true,
};

RemoteConfigViewModel _viewModel(
  http.Client client, {
  int? build = 20,
  String url = _url,
  DateTime? now,
}) {
  return RemoteConfigViewModel(
    RemoteConfigService(
      url: url,
      client: client,
      timeout: const Duration(milliseconds: 50),
      clock: now == null ? null : () => now,
    ),
    loadBuildNumber: () async => build,
  );
}

http.Client _serving(Map<String, dynamic> document) {
  return MockClient((_) async => http.Response(jsonEncode(document), 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('update gate', () {
    test('a hard requirement blocks a build below min_build', () async {
      final vm = _viewModel(_serving({'update_required': _update(hard: true)}));
      await vm.start();

      expect(vm.blockingUpdate, isNotNull);
      expect(vm.takeUpdateNudge(), isNull);
    });

    test(
      'a soft requirement nudges once per session and never blocks',
      () async {
        final vm = _viewModel(
          _serving({'update_required': _update(hard: false)}),
        );
        await vm.start();

        expect(vm.blockingUpdate, isNull);
        expect(vm.takeUpdateNudge(), isNotNull);
        expect(vm.takeUpdateNudge(), isNull);
      },
    );

    test('a build at or above min_build is not gated', () async {
      final vm = _viewModel(
        _serving({'update_required': _update(hard: true)}),
        build: 24,
      );
      await vm.start();

      expect(vm.requiredUpdate, isNull);
      expect(vm.blockingUpdate, isNull);
      expect(vm.takeUpdateNudge(), isNull);
    });

    test('min_build is read for the running platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final vm = _viewModel(
        _serving({'update_required': _update(hard: true)}),
        build: 25,
      );
      await vm.start();

      // 25 clears Android's 24 but not iOS's 30.
      expect(vm.blockingUpdate, isNotNull);
    });

    test('an unknown build number is never gated', () async {
      final vm = _viewModel(
        _serving({'update_required': _update(hard: true)}),
        build: null,
      );
      await vm.start();

      expect(vm.blockingUpdate, isNull);
    });
  });

  group('fetch failure', () {
    test('with nothing cached, nothing is gated', () async {
      final vm = _viewModel(
        MockClient((_) async => throw http.ClientException('offline')),
      );
      await vm.start();

      expect(vm.requiredUpdate, isNull);
      expect(await vm.takeAnnouncement(), isNull);
      expect(vm.paywallVisible, isFalse);
    });

    test('a timeout leaves the app open', () async {
      final vm = _viewModel(
        MockClient(
          (_) => Future<http.Response>.delayed(
            const Duration(seconds: 1),
            () => http.Response(
              jsonEncode({'update_required': _update(hard: true)}),
              200,
            ),
          ),
        ),
      );
      await vm.start();

      expect(vm.blockingUpdate, isNull);
    });

    test('keeps the last good document from the cache', () async {
      SharedPreferences.setMockInitialValues({
        'remote_config_document_v1': jsonEncode({'paywall_visible': true}),
      });
      final vm = _viewModel(MockClient((_) async => http.Response('', 500)));
      await vm.start();

      expect(vm.paywallVisible, isTrue);
    });

    test('a disabled URL makes no request and gates nothing', () async {
      var requests = 0;
      final vm = _viewModel(
        MockClient((_) async {
          requests += 1;
          return http.Response(
            jsonEncode({'update_required': _update(hard: true)}),
            200,
          );
        }),
        url: '',
      );
      await vm.start();
      await vm.refresh();

      expect(requests, 0);
      expect(vm.blockingUpdate, isNull);
    });
  });

  group('feature announcement', () {
    test('a show_once announcement is shown once per id for good', () async {
      final document = {'feature_announcement': _announcement};
      final first = _viewModel(_serving(document));
      await first.start();

      final shown = await first.takeAnnouncement();
      expect(shown?.id, 'maps-v2');
      expect(shown?.title, 'NEW MAP');
      expect(await first.takeAnnouncement(), isNull);

      // A cold start: a new view model over the same device storage.
      final second = _viewModel(_serving(document));
      await second.start();
      expect(await second.takeAnnouncement(), isNull);
    });

    test('a new id is shown even after an earlier one was', () async {
      final first = _viewModel(
        _serving({'feature_announcement': _announcement}),
      );
      await first.start();
      await first.takeAnnouncement();

      // Launched more than an hour later, so the new document is fetched.
      final second = _viewModel(
        _serving({
          'feature_announcement': {..._announcement, 'id': 'chat-v1'},
        }),
        now: DateTime.now().add(const Duration(hours: 2)),
      );
      await second.start();
      expect((await second.takeAnnouncement())?.id, 'chat-v1');
    });

    test('without show_once it comes back once per session', () async {
      final document = {
        'feature_announcement': {..._announcement, 'show_once': false},
      };
      final first = _viewModel(_serving(document));
      await first.start();
      expect(await first.takeAnnouncement(), isNotNull);
      expect(await first.takeAnnouncement(), isNull);

      final second = _viewModel(_serving(document));
      await second.start();
      expect(await second.takeAnnouncement(), isNotNull);
    });

    test('a disabled announcement is not shown', () async {
      final vm = _viewModel(
        _serving({
          'feature_announcement': {..._announcement, 'enabled': false},
        }),
      );
      await vm.start();

      expect(await vm.takeAnnouncement(), isNull);
    });
  });

  group('paywall gate', () {
    test('defaults to hidden', () async {
      final vm = _viewModel(_serving(const {}));
      expect(vm.paywallVisible, isFalse);
      await vm.start();
      expect(vm.paywallVisible, isFalse);
    });

    test('follows paywall_visible', () async {
      final vm = _viewModel(_serving({'paywall_visible': true}));
      await vm.start();
      expect(vm.paywallVisible, isTrue);
    });
  });

  test('notifies when a fetched document changes the answer', () async {
    final vm = _viewModel(_serving({'paywall_visible': true}));
    var notifications = 0;
    vm.addListener(() => notifications += 1);

    await vm.start();

    expect(notifications, 1);
  });
}
