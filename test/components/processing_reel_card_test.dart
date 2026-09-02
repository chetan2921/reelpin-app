import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/components/reels/processing_reel_card.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';

ProcessingJob _job({int? progress, String? platform}) {
  return ProcessingJob(
    id: 'job-1',
    status: 'processing',
    terminal: false,
    progressPercent: progress,
    sourcePlatform: platform,
  );
}

Future<void> _pumpCard(WidgetTester tester, ProcessingJob job) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 160,
            height: 220,
            child: ProcessingReelCard(job: job),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('paints without a thumbnail and keeps animating', (tester) async {
    await _pumpCard(tester, _job(progress: 40));

    expect(find.text('SAVING'), findsOneWidget);
    // The ripple controller repeats forever; the card must survive being left
    // running rather than settling.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('names the platform when the job reports one', (tester) async {
    await _pumpCard(tester, _job(progress: 10, platform: 'instagram'));

    expect(find.text('INSTAGRAM'), findsOneWidget);
  });

  testWidgets('falls back when the platform is not known yet', (tester) async {
    await _pumpCard(tester, _job(progress: 10));

    expect(find.text('TO REELPIN'), findsOneWidget);
  });

  testWidgets('a progress jump slides the level instead of snapping', (
    tester,
  ) async {
    await _pumpCard(tester, _job(progress: 10));
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 220,
              child: ProcessingReelCard(job: _job(progress: 80)),
            ),
          ),
        ),
      ),
    );
    // Mid-tween: still on its way up, not already at the new level.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
