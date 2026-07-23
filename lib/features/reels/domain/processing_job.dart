import 'package:reelpin/features/reels/domain/reel.dart';

class ProcessingJob {
  final String id;
  final String? normalizedUrl;
  final String? sourcePlatform;
  final String? sourceContentType;
  final String? sourceContentId;
  final String status;
  final String? currentStep;
  final int? progressPercent;
  final String? failureCode;
  final String? errorMessage;
  final bool terminal;
  final bool retryScheduled;
  final String? statusLabel;
  final String? statusMessage;
  final DateTime? nextRetryAt;
  final int? recommendedPollAfterSeconds;
  final bool retryable;
  final String? resultReelId;
  final Reel? reel;

  const ProcessingJob({
    required this.id,
    required this.status,
    this.normalizedUrl,
    this.sourcePlatform,
    this.sourceContentType,
    this.sourceContentId,
    this.currentStep,
    this.progressPercent,
    this.failureCode,
    this.errorMessage,
    required this.terminal,
    this.retryScheduled = false,
    this.statusLabel,
    this.statusMessage,
    this.nextRetryAt,
    this.recommendedPollAfterSeconds,
    this.retryable = false,
    this.resultReelId,
    this.reel,
  });

  factory ProcessingJob.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final reelPayload = json['reel'];
    final status = json['status']?.toString().toLowerCase() ?? 'queued';
    final currentStep = json['current_step']?.toString();
    return ProcessingJob(
      id: (json['id'] ?? json['job_id'])?.toString() ?? '',
      normalizedUrl: json['normalized_url']?.toString(),
      sourcePlatform: _normalizedNullableString(json['source_platform']),
      sourceContentType: _normalizedNullableString(json['source_content_type']),
      sourceContentId: json['source_content_id']?.toString(),
      status: status,
      currentStep: currentStep,
      progressPercent: _parseInt(json['progress_percent']),
      failureCode: json['failure_code']?.toString(),
      errorMessage: json['error_message']?.toString(),
      terminal:
          json['terminal'] == true ||
          (json['terminal'] == null &&
              (status == 'completed' ||
                  status == 'failed' ||
                  status == 'dead_lettered')),
      retryScheduled:
          json['retry_scheduled'] == true ||
          (status == 'queued' && currentStep == 'retry_scheduled'),
      statusLabel: json['status_label']?.toString(),
      statusMessage: json['status_message']?.toString(),
      nextRetryAt: parseDate(json['next_retry_at']),
      recommendedPollAfterSeconds: _parseInt(
        json['recommended_poll_after_seconds'],
      ),
      retryable: json['retryable'] == true,
      resultReelId: json['result_reel_id']?.toString(),
      reel: reelPayload is Map<String, dynamic>
          ? Reel.fromJson(reelPayload)
          : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isTerminalFailure => terminal && !isCompleted;
  bool get isRetryScheduled => retryScheduled;

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _normalizedNullableString(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
