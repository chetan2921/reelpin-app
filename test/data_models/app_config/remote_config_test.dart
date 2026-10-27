import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/app_config/remote_config.dart';

void main() {
  test('reads the full document', () {
    final config = RemoteConfig.fromJson({
      'update_required': {
        'enabled': true,
        'min_build': {'ios': 30, 'android': 24},
        'hard': true,
        'title': 'UPDATE NOW',
        'body': 'This build is retired.',
        'store_url': {
          'ios': 'https://apps.apple.com/app/id1',
          'android': 'https://play.google.com/store/apps/details?id=x',
        },
      },
      'feature_announcement': {
        'enabled': true,
        'id': 'maps-v2',
        'title': 'NEW MAP',
        'body': 'Pins cluster now.',
        'show_once': true,
      },
      'paywall_visible': true,
    });

    expect(config.updateRequired.enabled, isTrue);
    expect(config.updateRequired.minBuildIos, 30);
    expect(config.updateRequired.minBuildAndroid, 24);
    expect(config.updateRequired.hard, isTrue);
    expect(config.updateRequired.title, 'UPDATE NOW');
    expect(
      config.updateRequired.storeUrlFor(TargetPlatform.iOS),
      'https://apps.apple.com/app/id1',
    );
    expect(config.featureAnnouncement.id, 'maps-v2');
    expect(config.featureAnnouncement.showOnce, isTrue);
    expect(config.featureAnnouncement.isShowable, isTrue);
    expect(config.paywallVisible, isTrue);
  });

  test('an empty document gates nothing and hides the paywall', () {
    final config = RemoteConfig.fromJson(const {});

    expect(config.updateRequired.appliesTo(TargetPlatform.android, 1), isFalse);
    expect(config.featureAnnouncement.isShowable, isFalse);
    expect(config.paywallVisible, isFalse);
  });

  test('wrong types read as their closed defaults', () {
    final config = RemoteConfig.fromJson({
      'update_required': {
        'enabled': 'true',
        'min_build': {'android': '99'},
        'hard': 1,
      },
      'feature_announcement': 'maps-v2',
      'paywall_visible': 'yes',
    });

    expect(config.updateRequired.enabled, isFalse);
    expect(config.updateRequired.minBuildAndroid, isNull);
    expect(config.updateRequired.hard, isFalse);
    expect(config.featureAnnouncement.isShowable, isFalse);
    expect(config.paywallVisible, isFalse);
  });

  group('appliesTo', () {
    const requirement = UpdateRequirement(
      enabled: true,
      minBuildIos: 30,
      minBuildAndroid: 24,
    );

    test('gates a build below the platform minimum', () {
      expect(requirement.appliesTo(TargetPlatform.android, 23), isTrue);
      expect(requirement.appliesTo(TargetPlatform.iOS, 29), isTrue);
    });

    test('passes a build at or above the platform minimum', () {
      expect(requirement.appliesTo(TargetPlatform.android, 24), isFalse);
      expect(requirement.appliesTo(TargetPlatform.android, 40), isFalse);
      expect(requirement.appliesTo(TargetPlatform.iOS, 30), isFalse);
    });

    test('a platform with no minimum is never gated', () {
      const androidOnly = UpdateRequirement(enabled: true, minBuildAndroid: 24);
      expect(androidOnly.appliesTo(TargetPlatform.iOS, 1), isFalse);
    });

    test('a disabled requirement gates nothing', () {
      const disabled = UpdateRequirement(minBuildAndroid: 24);
      expect(disabled.appliesTo(TargetPlatform.android, 1), isFalse);
    });
  });
}
