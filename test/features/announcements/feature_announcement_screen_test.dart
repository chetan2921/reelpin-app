import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/features/announcements/presentation/feature_announcement_screen.dart';

void main() {
  testWidgets('shows feature update push content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FeatureAnnouncementScreen(
          title: 'YOUTUBE IS NOW ON REELPIN',
          body: 'Save YouTube Shorts and videos.',
        ),
      ),
    );

    expect(find.text('YOUTUBE IS NOW ON REELPIN'), findsOneWidget);
    expect(find.text('Save YouTube Shorts and videos.'), findsOneWidget);
    expect(find.text('BACK TO REELPIN'), findsOneWidget);
  });

  testWidgets('long announcement content scrolls without overflowing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        home: const FeatureAnnouncementScreen(
          title: 'A LONG FEATURE ANNOUNCEMENT THAT WRAPS ACROSS MANY LINES',
          body:
              'This update contains enough server-provided text to require '
              'scrolling on a short screen with enlarged system text.',
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
