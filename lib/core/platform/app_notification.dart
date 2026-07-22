import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

enum AppNotificationTarget {
  reelDetail,
  announcement,
  home,
  map,
  discover,
  profile,
}

enum AppNotificationOpenSource {
  foregroundLocal,
  backgroundRemote,
  terminatedRemote,
  terminatedLocal,
}

class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.target,
    required this.isMalformed,
    required this.data,
    this.notificationId,
    this.reelId,
    this.jobId,
    this.announcementId,
    this.campaignId,
  });

  final String title;
  final String body;
  final AppNotificationTarget target;
  final bool isMalformed;
  final Map<String, String> data;
  final String? notificationId;
  final String? reelId;
  final String? jobId;
  final String? announcementId;
  final String? campaignId;

  bool get isReelReady => target == AppNotificationTarget.reelDetail;

  factory AppNotification.fromRemoteMessage(RemoteMessage message) {
    return AppNotification.fromData(
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  factory AppNotification.fromData({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    final normalized = data.map(
      (key, value) => MapEntry(key, value?.toString().trim() ?? ''),
    );
    final schemaVersion = normalized['schema_version'];
    final type = normalized['type']?.toLowerCase();
    final target = normalized['target']?.toLowerCase();
    final notificationId = _nonEmpty(normalized['notification_id']);
    final resolvedTitle = _nonEmpty(title) ?? 'ReelPin';
    final resolvedBody = _nonEmpty(body) ?? '';

    if (schemaVersion == '1' &&
        type == 'reel_ready' &&
        target == 'reel_detail') {
      final reelId = _nonEmpty(normalized['reel_id']);
      final jobId = _nonEmpty(normalized['job_id']);
      if (notificationId != null && reelId != null && jobId != null) {
        return AppNotification(
          title: resolvedTitle,
          body: resolvedBody,
          target: AppNotificationTarget.reelDetail,
          isMalformed: false,
          data: normalized,
          notificationId: notificationId,
          reelId: reelId,
          jobId: jobId,
        );
      }
    }

    if (schemaVersion == '1' && type == 'feature_update') {
      final campaignId = _nonEmpty(normalized['campaign_id']);
      final notificationTarget = switch (target) {
        'announcement' => AppNotificationTarget.announcement,
        'home' => AppNotificationTarget.home,
        'map' => AppNotificationTarget.map,
        'discover' => AppNotificationTarget.discover,
        'profile' => AppNotificationTarget.profile,
        _ => null,
      };
      final announcementId = target == 'announcement'
          ? _nonEmpty(normalized['announcement_id'])
          : null;
      final hasRequiredAnnouncementId =
          target != 'announcement' || announcementId != null;
      if (notificationId != null &&
          campaignId != null &&
          notificationTarget != null &&
          hasRequiredAnnouncementId) {
        return AppNotification(
          title: resolvedTitle,
          body: resolvedBody,
          target: notificationTarget,
          isMalformed: false,
          data: normalized,
          notificationId: notificationId,
          announcementId: announcementId,
          campaignId: campaignId,
        );
      }
    }

    return AppNotification(
      title: resolvedTitle,
      body: resolvedBody,
      target: AppNotificationTarget.home,
      isMalformed: true,
      data: normalized,
      notificationId: notificationId,
    );
  }

  String toLocalPayload() {
    return jsonEncode({'title': title, 'body': body, 'data': data});
  }

  static AppNotification fromLocalPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return AppNotification.fromData(data: const {});
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return AppNotification.fromData(data: const {});
      }
      final rawData = decoded['data'];
      return AppNotification.fromData(
        data: rawData is Map
            ? rawData.map((key, value) => MapEntry(key.toString(), value))
            : const {},
        title: decoded['title']?.toString(),
        body: decoded['body']?.toString(),
      );
    } catch (_) {
      return AppNotification.fromData(data: const {});
    }
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class OpenedAppNotification {
  const OpenedAppNotification({
    required this.notification,
    required this.source,
  });

  final AppNotification notification;
  final AppNotificationOpenSource source;
}
