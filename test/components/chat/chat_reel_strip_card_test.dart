import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_reel_strip_card.dart';
import 'package:reelpin/data_models/reels/reel.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 118, child: child)),
);

const _reel = Reel(
  id: 'r1',
  userId: 'u1',
  url: 'https://example.com/r1',
  title: 'Ichiran Ramen Trip',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Food & Drink',
  subCategory: 'Ramen Shops',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  sourcePlatform: 'instagram',
  relativeDate: '2 DAYS AGO',
);

void main() {
  testWidgets('shows the title and the pin', (tester) async {
    await tester.pumpWidget(
      _host(ChatReelStripCard(reel: _reel, onTap: () {})),
    );

    expect(find.text('Ichiran Ramen Trip'), findsOneWidget);
    final pinFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/pin.png',
    );
    expect(pinFinder, findsOneWidget);
  });

  testWidgets('does not show the category tag, source icon or relative date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(ChatReelStripCard(reel: _reel, onTap: () {})),
    );

    expect(find.text('RAMEN SHOPS'), findsNothing);
    expect(find.text('2 DAYS AGO'), findsNothing);
    final sourceIconFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.contains('instagram'),
    );
    expect(sourceIconFinder, findsNothing);
  });

  testWidgets('tapping the card calls back', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(ChatReelStripCard(reel: _reel, onTap: () => tapped = true)),
    );

    await tester.tap(find.byType(ChatReelStripCard));
    expect(tapped, isTrue);
  });
}
