import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/notifications/app_notification.dart';
import 'package:reelpin/services/notifications/notification_tap_handler.dart';

void main() {
  test('background reel tap tracks the open and routes to its reel', () async {
    final handler = NotificationTapHandler();
    final tracked = <String>[];
    final openedReels = <String>[];

    final handled = await handler.handle(
      OpenedAppNotification(
        notification: _reelNotification,
        source: AppNotificationOpenSource.backgroundRemote,
      ),
      trackOpen: (id) async => tracked.add(id),
      openReel: (id) async => openedReels.add(id),
      openAnnouncement: (_) async => fail('Unexpected announcement route'),
      openHome: () async => fail('Unexpected Home route'),
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (_) async => fail('Unexpected collection route'),
    );

    expect(handled, isTrue);
    expect(tracked, ['notification-reel']);
    expect(openedReels, ['reel-1']);
  });

  test('terminated feature tap routes to its announcement', () async {
    final handler = NotificationTapHandler();
    AppNotification? openedAnnouncement;

    await handler.handle(
      OpenedAppNotification(
        notification: _featureNotification,
        source: AppNotificationOpenSource.terminatedRemote,
      ),
      trackOpen: (_) async {},
      openReel: (_) async => fail('Unexpected reel route'),
      openAnnouncement: (notification) async {
        openedAnnouncement = notification;
      },
      openHome: () async => fail('Unexpected Home route'),
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (_) async => fail('Unexpected collection route'),
    );

    expect(openedAnnouncement?.announcementId, 'youtube_support_v1');
  });

  test('malformed foreground tap routes Home and records a valid ID', () async {
    final handler = NotificationTapHandler();
    var openedHome = false;
    final tracked = <String>[];

    await handler.handle(
      OpenedAppNotification(
        notification: AppNotification.fromData(
          data: const {'notification_id': 'notification-malformed'},
        ),
        source: AppNotificationOpenSource.foregroundLocal,
      ),
      trackOpen: (id) async => tracked.add(id),
      openReel: (_) async => fail('Unexpected reel route'),
      openAnnouncement: (_) async => fail('Unexpected announcement route'),
      openHome: () async => openedHome = true,
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (_) async => fail('Unexpected collection route'),
    );

    expect(openedHome, isTrue);
    expect(tracked, ['notification-malformed']);
  });

  test('duplicate taps are handled once', () async {
    final handler = NotificationTapHandler();
    var openCount = 0;
    final opened = OpenedAppNotification(
      notification: _reelNotification,
      source: AppNotificationOpenSource.backgroundRemote,
    );

    Future<bool> handle() => handler.handle(
      opened,
      trackOpen: (_) async {},
      openReel: (_) async => openCount += 1,
      openAnnouncement: (_) async {},
      openHome: () async {},
      openMap: () async {},
      openDiscover: () async {},
      openProfile: () async {},
      openAppUpdate: () async {},
      openCollection: (_) async {},
    );

    expect(await handle(), isTrue);
    expect(await handle(), isFalse);
    expect(openCount, 1);
  });

  test('malformed reel target falls back to Home', () async {
    final handler = NotificationTapHandler();
    var openedHome = false;

    final handled = await handler.handle(
      const OpenedAppNotification(
        notification: AppNotification(
          title: 'Ready',
          body: 'Tap to open.',
          target: AppNotificationTarget.reelDetail,
          isMalformed: true,
          data: {},
          notificationId: 'notification-missing-reel',
        ),
        source: AppNotificationOpenSource.backgroundRemote,
      ),
      trackOpen: (_) async {},
      openReel: (_) async => fail('Unexpected reel route'),
      openAnnouncement: (_) async => fail('Unexpected announcement route'),
      openHome: () async => openedHome = true,
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (_) async => fail('Unexpected collection route'),
    );

    expect(handled, isTrue);
    expect(openedHome, isTrue);
  });

  test('records the open before starting navigation', () async {
    final handler = NotificationTapHandler();
    final events = <String>[];

    await handler.handle(
      OpenedAppNotification(
        notification: _reelNotification,
        source: AppNotificationOpenSource.backgroundRemote,
      ),
      trackOpen: (_) async => events.add('track'),
      openReel: (_) async => events.add('navigate'),
      openAnnouncement: (_) async => fail('Unexpected announcement route'),
      openHome: () async => fail('Unexpected Home route'),
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (_) async => fail('Unexpected collection route'),
    );

    expect(events, ['track', 'navigate']);
  });

  test('new feature targets route from every notification tap state', () async {
    final cases =
        <
          ({
            String target,
            AppNotificationOpenSource source,
            AppNotificationTarget expected,
          })
        >[
          (
            target: 'home',
            source: AppNotificationOpenSource.foregroundLocal,
            expected: AppNotificationTarget.home,
          ),
          (
            target: 'map',
            source: AppNotificationOpenSource.backgroundRemote,
            expected: AppNotificationTarget.map,
          ),
          (
            target: 'discover',
            source: AppNotificationOpenSource.terminatedRemote,
            expected: AppNotificationTarget.discover,
          ),
          (
            target: 'profile',
            source: AppNotificationOpenSource.terminatedLocal,
            expected: AppNotificationTarget.profile,
          ),
          (
            target: 'app_update',
            source: AppNotificationOpenSource.backgroundRemote,
            expected: AppNotificationTarget.appUpdate,
          ),
        ];

    for (final testCase in cases) {
      final handler = NotificationTapHandler();
      AppNotificationTarget? openedTarget;
      final tracked = <String>[];
      final notification = _featureTargetNotification(testCase.target);

      final handled = await handler.handle(
        OpenedAppNotification(
          notification: notification,
          source: testCase.source,
        ),
        trackOpen: (id) async => tracked.add(id),
        openReel: (_) async => fail('Unexpected reel route'),
        openAnnouncement: (_) async => fail('Unexpected announcement route'),
        openHome: () async => openedTarget = AppNotificationTarget.home,
        openMap: () async => openedTarget = AppNotificationTarget.map,
        openDiscover: () async => openedTarget = AppNotificationTarget.discover,
        openProfile: () async => openedTarget = AppNotificationTarget.profile,
        openAppUpdate: () async =>
            openedTarget = AppNotificationTarget.appUpdate,
        openCollection: (_) async => fail('Unexpected collection route'),
      );

      expect(handled, isTrue);
      expect(openedTarget, testCase.expected);
      expect(tracked, ['notification-${testCase.target}']);
    }
  });

  test('collection tap routes to the collection it names', () async {
    final handler = NotificationTapHandler();
    final openedCollections = <String>[];
    final tracked = <String>[];

    final handled = await handler.handle(
      OpenedAppNotification(
        notification: _collectionNotification,
        source: AppNotificationOpenSource.backgroundRemote,
      ),
      trackOpen: (id) async => tracked.add(id),
      openReel: (_) async => fail('Unexpected reel route'),
      openAnnouncement: (_) async => fail('Unexpected announcement route'),
      openHome: () async => fail('Unexpected Home route'),
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (id) async => openedCollections.add(id),
    );

    expect(handled, isTrue);
    expect(tracked, ['notification-collection']);
    expect(openedCollections, ['collection-1']);
  });

  test('collection tap without an id falls back to Home', () async {
    final handler = NotificationTapHandler();
    var openedHome = false;

    await handler.handle(
      const OpenedAppNotification(
        notification: AppNotification(
          title: 'Weekend Hikes',
          body: '2 new reels added.',
          target: AppNotificationTarget.collection,
          isMalformed: false,
          data: {},
          notificationId: 'notification-missing-collection',
        ),
        source: AppNotificationOpenSource.backgroundRemote,
      ),
      trackOpen: (_) async {},
      openReel: (_) async => fail('Unexpected reel route'),
      openAnnouncement: (_) async => fail('Unexpected announcement route'),
      openHome: () async => openedHome = true,
      openMap: () async => fail('Unexpected Map route'),
      openDiscover: () async => fail('Unexpected Discover route'),
      openProfile: () async => fail('Unexpected Profile route'),
      openAppUpdate: () async => fail('Unexpected app update route'),
      openCollection: (_) async => fail('Unexpected collection route'),
    );

    expect(openedHome, isTrue);
  });
}

final _collectionNotification = AppNotification.fromData(
  title: 'Weekend Hikes',
  body: '2 new reels added.',
  data: const {
    'schema_version': '1',
    'notification_id': 'notification-collection',
    'type': 'collection_update',
    'target': 'collection',
    'collection_id': 'collection-1',
  },
);

AppNotification _featureTargetNotification(String target) {
  return AppNotification.fromData(
    title: 'Feature update',
    body: 'Tap to open.',
    data: {
      'schema_version': '1',
      'notification_id': 'notification-$target',
      'type': 'feature_update',
      'target': target,
      'campaign_id': 'campaign-1',
    },
  );
}

final _reelNotification = AppNotification.fromData(
  title: 'Ready',
  body: 'Tap to open.',
  data: const {
    'schema_version': '1',
    'notification_id': 'notification-reel',
    'type': 'reel_ready',
    'target': 'reel_detail',
    'reel_id': 'reel-1',
    'job_id': 'job-1',
  },
);

final _featureNotification = AppNotification.fromData(
  title: 'YouTube is ready',
  body: 'Save Shorts and videos.',
  data: const {
    'schema_version': '1',
    'notification_id': 'notification-feature',
    'type': 'feature_update',
    'target': 'announcement',
    'announcement_id': 'youtube_support_v1',
    'campaign_id': 'campaign-1',
  },
);
