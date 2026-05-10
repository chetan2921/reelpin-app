import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/services/share_flow_analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('share flow analytics persist counters and last outcome', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ShareFlowAnalyticsService();

    await service.recordShareDetected('https://example.com/reel');
    await service.recordDuplicateShareSkipped('https://example.com/reel');
    await service.recordEnqueueStarted('https://example.com/reel');
    await service.recordEnqueueFailed(
      'https://example.com/reel',
      Exception('boom'),
    );

    final snapshot = await service.loadSnapshot();

    expect(snapshot.detectedCount, 1);
    expect(snapshot.duplicateCount, 1);
    expect(snapshot.startedCount, 1);
    expect(snapshot.succeededCount, 0);
    expect(snapshot.failedCount, 1);
    expect(snapshot.lastSharedUrl, 'https://example.com/reel');
    expect(snapshot.lastFailure, contains('boom'));
  });
}
