import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/features/reels/domain/reel.dart';
import 'package:reelpin/features/reels/presentation/detail/reel_detail_screen.dart';

void main() {
  testWidgets('share card renders long reel details without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final reel = _shareReel(
      contentType: 'carousel',
      title:
          'A very long reel title that should still look clean when shared with friends across the square card without being cut at the top',
      summary:
          'This reel has a long summary with enough detail to stress the card layout. It should describe what happened, why it matters, and what the viewer can quickly remember later without making the poster overflow. Extra sentence that should be clipped before the card gets crowded. Another extra sentence should not take over the poster.',
      keyFacts: const [
        'The reel highlights three spots that can be visited in one afternoon.',
        'The creator recommends starting early to avoid crowds and queues.',
        'The final location is best for sunset photos and dinner nearby.',
        'The route works better on foot than by car.',
        'This fifth fact should stay out of the share card.',
      ],
      actionableItems: const [
        'Book the first stop before noon.',
        'Walk between each stop instead of driving.',
        'Save the final location for sunset.',
        'This fourth action should stay out of the share card.',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: ReelShareCard(reel: reel),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final cardSize = tester.getSize(find.byType(ReelShareCard));
    expect(cardSize.width, cardSize.height);
    expect(find.text('CAROUSEL'), findsOneWidget);
    expect(find.text('REEL'), findsNothing);
    expect(find.text('POST'), findsNothing);
    expect(find.textContaining('https://www.instagram.com'), findsNothing);
    expect(
      find.textContaining('A VERY LONG LOCATION NAME IN DOWNTOWN MANHATTAN'),
      findsNothing,
    );
    expect(find.textContaining('Avery Longname'), findsNothing);
    expect(find.textContaining('This fifth fact'), findsNothing);
    expect(find.textContaining('Save the final location'), findsOneWidget);
    expect(find.textContaining('This fourth action'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share card stays sparse with only summary content', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: ReelShareCard(
              reel: _shareReel(
                contentType: 'post',
                summary:
                    'A short useful note that should have room to breathe.',
                keyFacts: const [],
                actionableItems: const [],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('POST'), findsOneWidget);
    expect(find.text('SUMMARY'), findsOneWidget);
    expect(find.text('KEY FACTS'), findsNothing);
    expect(find.text('TOP ACTIONS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Reel _shareReel({
  String contentType = 'reel',
  String title = 'A saved reel worth remembering',
  String summary =
      'This reel has a clear summary that should be readable on the share card.',
  List<String> keyFacts = const [
    'The reel highlights three spots that can be visited in one afternoon.',
    'The creator recommends starting early to avoid crowds.',
  ],
  List<String> actionableItems = const [
    'Book the first stop before noon.',
    'Walk between each stop instead of driving.',
  ],
}) {
  return Reel(
    id: 'reel-123',
    userId: 'user-123',
    url: 'https://www.instagram.com/reel/example/',
    title: title,
    summary: summary,
    caption: '',
    transcript: '',
    category: 'Travel',
    subCategory: 'City Guide',
    contentType: contentType,
    keyFacts: keyFacts,
    locations: const [
      Location(
        name: 'A very long location name in downtown Manhattan',
        googleMapsUrl: 'https://maps.google.com/?q=manhattan',
      ),
      Location(name: 'Second location with a long label'),
    ],
    peopleMentioned: const ['Avery Longname', 'Sam Rivera'],
    actionableItems: actionableItems,
  );
}
