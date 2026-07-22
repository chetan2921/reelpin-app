import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/core/platform/app_notification.dart';

void main() {
  test('parses schema version 1 reel-ready payload', () {
    final notification = AppNotification.fromRemoteMessage(
      RemoteMessage(
        notification: const RemoteNotification(
          title: 'YOUR REEL IS READY',
          body: 'Tap to open it.',
        ),
        data: const {
          'schema_version': '1',
          'notification_id': 'notification-1',
          'type': 'reel_ready',
          'target': 'reel_detail',
          'reel_id': 'reel-1',
          'job_id': 'job-1',
        },
      ),
    );

    expect(notification.isMalformed, isFalse);
    expect(notification.target, AppNotificationTarget.reelDetail);
    expect(notification.notificationId, 'notification-1');
    expect(notification.reelId, 'reel-1');
    expect(notification.jobId, 'job-1');
  });

  test('parses schema version 1 feature-update payload', () {
    final notification = AppNotification.fromData(
      title: 'YOUTUBE IS NOW ON REELPIN',
      body: 'You can save Shorts and videos.',
      data: const {
        'schema_version': '1',
        'notification_id': 'notification-2',
        'type': 'feature_update',
        'target': 'announcement',
        'announcement_id': 'youtube_support_v1',
        'campaign_id': 'campaign-1',
      },
    );

    expect(notification.isMalformed, isFalse);
    expect(notification.target, AppNotificationTarget.announcement);
    expect(notification.announcementId, 'youtube_support_v1');
    expect(notification.campaignId, 'campaign-1');
  });

  test('parses feature-update navigation targets', () {
    const targets = {
      'home': AppNotificationTarget.home,
      'map': AppNotificationTarget.map,
      'discover': AppNotificationTarget.discover,
      'profile': AppNotificationTarget.profile,
    };

    for (final entry in targets.entries) {
      final notification = AppNotification.fromData(
        data: {
          'schema_version': '1',
          'notification_id': 'notification-${entry.key}',
          'type': 'feature_update',
          'target': entry.key,
          'campaign_id': 'campaign-1',
        },
      );

      expect(notification.target, entry.value);
      expect(notification.isMalformed, isFalse);
      expect(notification.campaignId, 'campaign-1');
      expect(notification.announcementId, isNull);
    }
  });

  test(
    'feature updates require campaign and announcement IDs as applicable',
    () {
      final missingCampaignId = AppNotification.fromData(
        data: const {
          'schema_version': '1',
          'notification_id': 'notification-map',
          'type': 'feature_update',
          'target': 'map',
        },
      );
      final missingAnnouncementId = AppNotification.fromData(
        data: const {
          'schema_version': '1',
          'notification_id': 'notification-announcement',
          'type': 'feature_update',
          'target': 'announcement',
          'campaign_id': 'campaign-1',
        },
      );

      expect(missingCampaignId.target, AppNotificationTarget.home);
      expect(missingCampaignId.isMalformed, isTrue);
      expect(missingAnnouncementId.target, AppNotificationTarget.home);
      expect(missingAnnouncementId.isMalformed, isTrue);
    },
  );

  test('malformed and unknown payloads fall back to Home', () {
    final missingReelId = AppNotification.fromData(
      data: const {
        'schema_version': '1',
        'notification_id': 'notification-3',
        'type': 'reel_ready',
        'target': 'reel_detail',
        'job_id': 'job-1',
      },
    );
    final unknown = AppNotification.fromData(
      data: const {
        'schema_version': '1',
        'notification_id': 'notification-unknown',
        'type': 'feature_update',
        'target': 'external_url',
        'campaign_id': 'campaign-1',
      },
    );
    final missingSchemaVersion = AppNotification.fromData(
      data: const {
        'notification_id': 'notification-profile',
        'type': 'feature_update',
        'target': 'profile',
        'campaign_id': 'campaign-1',
      },
    );

    expect(missingReelId.target, AppNotificationTarget.home);
    expect(missingReelId.isMalformed, isTrue);
    expect(unknown.target, AppNotificationTarget.home);
    expect(unknown.isMalformed, isTrue);
    expect(missingSchemaVersion.target, AppNotificationTarget.home);
    expect(missingSchemaVersion.isMalformed, isTrue);
  });

  test('foreground local payload preserves its navigation data', () {
    final original = AppNotification.fromData(
      title: 'Open the map',
      body: 'See what you saved nearby.',
      data: const {
        'schema_version': '1',
        'notification_id': 'notification-4',
        'type': 'feature_update',
        'target': 'map',
        'campaign_id': 'campaign-4',
      },
    );

    final decoded = AppNotification.fromLocalPayload(original.toLocalPayload());

    expect(decoded.target, AppNotificationTarget.map);
    expect(decoded.notificationId, 'notification-4');
    expect(decoded.campaignId, 'campaign-4');
  });
}
