import 'reel.dart';

class ProcessingJob {
  final String id;
  final String status;
  final String? currentStep;
  final String? failureCode;
  final String? errorMessage;
  final String? statusMessage;
  final DateTime? nextRetryAt;
  final int? recommendedPollAfterSeconds;
  final bool retryable;
  final String? resultReelId;
  final Reel? reel;

  const ProcessingJob({
    required this.id,
    required this.status,
    this.currentStep,
    this.failureCode,
    this.errorMessage,
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
    return ProcessingJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? 'queued',
      currentStep: json['current_step']?.toString(),
      failureCode: json['failure_code']?.toString(),
      errorMessage: json['error_message']?.toString(),
      statusMessage: json['status_message']?.toString(),
      nextRetryAt: parseDate(json['next_retry_at']),
      recommendedPollAfterSeconds: json['recommended_poll_after_seconds'] is num
          ? (json['recommended_poll_after_seconds'] as num).toInt()
          : null,
      retryable: json['retryable'] == true,
      resultReelId: json['result_reel_id']?.toString(),
      reel: reelPayload is Map<String, dynamic>
          ? Reel.fromJson(reelPayload)
          : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isTerminalFailure => status == 'failed' || status == 'dead_lettered';
  bool get isRetryScheduled =>
      status == 'queued' && currentStep == 'retry_scheduled';
}
