import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/features/reels/domain/processing_job.dart';

void main() {
  test('parses complete X processing-job metadata', () {
    final job = ProcessingJob.fromJson({
      'id': 'job-x-1',
      'normalized_url': 'https://x.com/OpenAI/status/1234567890',
      'source_platform': 'X',
      'source_content_type': 'POST',
      'source_content_id': '1234567890',
      'status': 'processing',
      'current_step': 'fetching_post',
      'progress_percent': 45,
      'failure_code': null,
      'error_message': null,
      'terminal': false,
      'retry_scheduled': false,
      'retryable': false,
      'status_label': 'Reading X post',
      'status_message': 'Reading the public X post.',
      'recommended_poll_after_seconds': 3,
      'result_reel_id': null,
      'reel': null,
    });

    expect(job.id, 'job-x-1');
    expect(job.normalizedUrl, 'https://x.com/OpenAI/status/1234567890');
    expect(job.sourcePlatform, 'x');
    expect(job.sourceContentType, 'post');
    expect(job.sourceContentId, '1234567890');
    expect(job.progressPercent, 45);
    expect(job.terminal, isFalse);
    expect(job.recommendedPollAfterSeconds, 3);
  });

  test('keeps retryable X upstream failures non-terminal', () {
    final job = ProcessingJob.fromJson({
      'id': 'job-x-2',
      'status': 'failed',
      'failure_code': 'x_oembed_timeout',
      'terminal': false,
      'retry_scheduled': true,
      'retryable': true,
    });

    expect(job.failureCode, 'x_oembed_timeout');
    expect(job.retryable, isTrue);
    expect(job.isRetryScheduled, isTrue);
    expect(job.isTerminalFailure, isFalse);
  });

  test('unknown source values remain parseable', () {
    final job = ProcessingJob.fromJson({
      'id': 'job-future',
      'status': 'future_status',
      'source_platform': 'FutureNetwork',
      'source_content_type': 'FutureType',
      'terminal': false,
    });

    expect(job.status, 'future_status');
    expect(job.sourcePlatform, 'futurenetwork');
    expect(job.sourceContentType, 'futuretype');
    expect(job.isTerminalFailure, isFalse);
  });
}
