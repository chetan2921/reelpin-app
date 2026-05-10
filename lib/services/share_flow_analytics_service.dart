import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ShareFlowAnalyticsSnapshot {
  const ShareFlowAnalyticsSnapshot({
    required this.detectedCount,
    required this.duplicateCount,
    required this.startedCount,
    required this.succeededCount,
    required this.failedCount,
    this.lastSharedUrl,
    this.lastFailure,
    this.lastEventAt,
  });

  final int detectedCount;
  final int duplicateCount;
  final int startedCount;
  final int succeededCount;
  final int failedCount;
  final String? lastSharedUrl;
  final String? lastFailure;
  final DateTime? lastEventAt;

  Map<String, dynamic> toJson() => {
    'detected_count': detectedCount,
    'duplicate_count': duplicateCount,
    'started_count': startedCount,
    'succeeded_count': succeededCount,
    'failed_count': failedCount,
    if (lastSharedUrl != null) 'last_shared_url': lastSharedUrl,
    if (lastFailure != null) 'last_failure': lastFailure,
    if (lastEventAt != null) 'last_event_at': lastEventAt!.toUtc().toIso8601String(),
  };

  factory ShareFlowAnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    final lastEventAtRaw = json['last_event_at'] as String?;
    return ShareFlowAnalyticsSnapshot(
      detectedCount: (json['detected_count'] as num?)?.toInt() ?? 0,
      duplicateCount: (json['duplicate_count'] as num?)?.toInt() ?? 0,
      startedCount: (json['started_count'] as num?)?.toInt() ?? 0,
      succeededCount: (json['succeeded_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      lastSharedUrl: json['last_shared_url'] as String?,
      lastFailure: json['last_failure'] as String?,
      lastEventAt: lastEventAtRaw == null || lastEventAtRaw.isEmpty
          ? null
          : DateTime.tryParse(lastEventAtRaw),
    );
  }

  ShareFlowAnalyticsSnapshot copyWith({
    int? detectedCount,
    int? duplicateCount,
    int? startedCount,
    int? succeededCount,
    int? failedCount,
    String? lastSharedUrl,
    String? lastFailure,
    DateTime? lastEventAt,
  }) {
    return ShareFlowAnalyticsSnapshot(
      detectedCount: detectedCount ?? this.detectedCount,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      startedCount: startedCount ?? this.startedCount,
      succeededCount: succeededCount ?? this.succeededCount,
      failedCount: failedCount ?? this.failedCount,
      lastSharedUrl: lastSharedUrl ?? this.lastSharedUrl,
      lastFailure: lastFailure ?? this.lastFailure,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }
}

class ShareFlowAnalyticsService {
  static const _storageKey = 'share_flow_analytics_v1';

  Future<ShareFlowAnalyticsSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_storageKey);
    if (payload == null || payload.trim().isEmpty) {
      return const ShareFlowAnalyticsSnapshot(
        detectedCount: 0,
        duplicateCount: 0,
        startedCount: 0,
        succeededCount: 0,
        failedCount: 0,
      );
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return ShareFlowAnalyticsSnapshot.fromJson(decoded);
    } catch (_) {
      await prefs.remove(_storageKey);
      return const ShareFlowAnalyticsSnapshot(
        detectedCount: 0,
        duplicateCount: 0,
        startedCount: 0,
        succeededCount: 0,
        failedCount: 0,
      );
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> recordShareDetected(String url) {
    return _update(
      (current) => current.copyWith(
        detectedCount: current.detectedCount + 1,
        lastSharedUrl: url,
        lastEventAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordDuplicateShareSkipped(String url) {
    return _update(
      (current) => current.copyWith(
        duplicateCount: current.duplicateCount + 1,
        lastSharedUrl: url,
        lastEventAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordEnqueueStarted(String url) {
    return _update(
      (current) => current.copyWith(
        startedCount: current.startedCount + 1,
        lastSharedUrl: url,
        lastEventAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordEnqueueSucceeded(String url) {
    return _update(
      (current) => current.copyWith(
        succeededCount: current.succeededCount + 1,
        lastSharedUrl: url,
        lastFailure: null,
        lastEventAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordEnqueueFailed(String url, Object error) {
    return _update(
      (current) => current.copyWith(
        failedCount: current.failedCount + 1,
        lastSharedUrl: url,
        lastFailure: error.toString(),
        lastEventAt: DateTime.now(),
      ),
    );
  }

  Future<void> _update(
    ShareFlowAnalyticsSnapshot Function(ShareFlowAnalyticsSnapshot current)
    transform,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final next = transform(await loadSnapshot());
    await prefs.setString(_storageKey, jsonEncode(next.toJson()));
  }
}
