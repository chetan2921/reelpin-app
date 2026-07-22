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
}
