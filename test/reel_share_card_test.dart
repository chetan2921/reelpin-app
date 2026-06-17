import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/screens/reel_detail_screen.dart';

void main() {
  testWidgets('share card renders long reel details without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final reel = Reel(
      id: 'reel-123',
      userId: 'user-123',
      url: 'https://www.instagram.com/reel/example/',
      title:
          'A very long reel title that should still look clean when shared with friends across the square card without being cut at the top',
      summary:
          'This reel has a long summary with enough detail to stress the card layout. It should describe what happened, why it matters, and what the viewer can quickly remember later without making the poster overflow.',
      caption: '',
      transcript: '',
      category: 'Travel',
      subCategory: 'City Guide',
      keyFacts: const [
        'The reel highlights three spots that can be visited in one afternoon.',
        'The creator recommends starting early to avoid crowds and queues.',
        'The final location is best for sunset photos and dinner nearby.',
        'The route works better on foot than by car.',
      ],
      locations: const [
        Location(
          name: 'A very long location name in downtown Manhattan',
          googleMapsUrl: 'https://maps.google.com/?q=manhattan',
        ),
        Location(name: 'Second location with a long label'),
      ],
      peopleMentioned: const ['Avery Longname', 'Sam Rivera'],
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
    expect(find.textContaining('https://www.instagram.com'), findsNothing);
    expect(
      find.textContaining('A VERY LONG LOCATION NAME IN DOWNTOWN MANHATTAN'),
      findsNothing,
    );
    expect(find.textContaining('Avery Longname'), findsNothing);
    expect(find.textContaining('Save the final location'), findsOneWidget);
    expect(find.textContaining('This fourth action'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
