import 'dart:async';

import 'package:reelpin/data_models/notifications/app_notification.dart';
import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';

typedef NotificationAction = Future<void> Function();
typedef ReelNotificationAction = Future<void> Function(String reelId);
typedef CollectionNotificationAction =
    Future<void> Function(String collectionId);
typedef AnnouncementNotificationAction =
    Future<void> Function(AppNotification notification);
typedef NotificationOpenTracker = Future<void> Function(String notificationId);

class NotificationTapHandler {
  final Set<String> _handledNotificationOpens = {};

  Future<bool> handle(
    OpenedAppNotification opened, {
    required NotificationOpenTracker trackOpen,
    required ReelNotificationAction openReel,
    required AnnouncementNotificationAction openAnnouncement,
    required NotificationAction openHome,
    required NotificationAction openMap,
    required NotificationAction openDiscover,
    required NotificationAction openProfile,
    required NotificationAction openAppUpdate,
    required CollectionNotificationAction openCollection,
  }) async {
    final notification = opened.notification;
    final dedupeKey =
        notification.notificationId ??
        '${notification.target.name}:${notification.reelId ?? notification.announcementId ?? notification.collectionId ?? notification.title}';
    if (!_handledNotificationOpens.add(dedupeKey)) return false;

    unawaited(
      AnalyticsService.log(
        AnalyticsEvent.notificationOpened,
        parameters: {'target': notification.target.name},
      ),
    );

    final notificationId = notification.notificationId;
    final tracking = notificationId == null
        ? Future<void>.value()
        : trackOpen(notificationId);
    await tracking;

    switch (notification.target) {
      case AppNotificationTarget.reelDetail:
        final reelId = notification.reelId;
        if (reelId == null || reelId.isEmpty) {
          await openHome();
        } else {
          await openReel(reelId);
        }
        break;
      case AppNotificationTarget.announcement:
        await openAnnouncement(notification);
        break;
      case AppNotificationTarget.home:
        await openHome();
        break;
      case AppNotificationTarget.map:
        await openMap();
        break;
      case AppNotificationTarget.discover:
        await openDiscover();
        break;
      case AppNotificationTarget.profile:
        await openProfile();
        break;
      case AppNotificationTarget.appUpdate:
        await openAppUpdate();
        break;
      case AppNotificationTarget.collection:
        final collectionId = notification.collectionId;
        if (collectionId == null || collectionId.isEmpty) {
          await openHome();
        } else {
          await openCollection(collectionId);
        }
        break;
    }

    return true;
  }

  void clear() {
    _handledNotificationOpens.clear();
  }
}
