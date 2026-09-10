import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_chart_block.dart';
import 'package:reelpin/components/chat/chat_reel_strip.dart';
import 'package:reelpin/components/chat/chat_table_block.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 400, child: child)),
);

/// Every fetch fails, matching the pre-fix behaviour these tests exercise:
/// an id absent from `library` never resolves to a card.
ChatReelCache _failingCache() =>
    ChatReelCache((_) async => throw Exception('not found'));

Reel _reel(String id, String title) => Reel(
  id: id,
  userId: 'u1',
  url: 'https://example.com/$id',
  title: title,
  summary: '',
  caption: '',
  transcript: '',
  category: 'Food',
  subCategory: 'Ramen',
  keyFacts: const [],
  locations: const [],
  peopleMentioned: const [],
  actionableItems: const [],
);

void main() {
  testWidgets('the strip renders only ids the library still has', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatReelStrip(
          reelIds: const ['r1', 'r-deleted'],
          library: [_reel('r1', 'Ichiran')],
          reelCache: _failingCache(),
          onTapReel: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ichiran'), findsOneWidget);
  });

  testWidgets('the strip shows no label when nothing resolves', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatReelStrip(
          reelIds: const ['gone'],
          library: const [],
          reelCache: _failingCache(),
          onTapReel: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FROM YOUR SAVES · SWIPE →'), findsNothing);
  });

  testWidgets("the last card's pin is not clipped by the strip", (
    tester,
  ) async {
    // Baseline device size — the same one ReelCard's overhang is tuned
    // against — so the assertion isn't at the mercy of the test runner's
    // default window size.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Enough cards that the strip actually scrolls — the clip only shows up
    // once the trailing edge is real, not on a strip that fits on screen.
    final reels = List.generate(6, (i) => _reel('r$i', 'Reel $i'));
    await tester.pumpWidget(
      _host(
        ChatReelStrip(
          reelIds: reels.map((r) => r.id).toList(),
          library: reels,
          reelCache: _failingCache(),
          onTapReel: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(-2000, 0));
    await tester.pumpAndSettle();

    final listViewRect = tester.getRect(find.byType(ListView));
    final pinFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/pin.png',
    );
    expect(pinFinder, findsWidgets);
    final lastPinRect = tester.getRect(pinFinder.last);

    expect(lastPinRect.right, lessThanOrEqualTo(listViewRect.right + 0.5));
    expect(lastPinRect.top, greaterThanOrEqualTo(listViewRect.top - 0.5));
  });

  testWidgets('tapping a card in the strip calls back with that reel', (
    tester,
  ) async {
    Reel? tapped;
    await tester.pumpWidget(
      _host(
        ChatReelStrip(
          reelIds: const ['r1'],
          library: [_reel('r1', 'Ichiran')],
          reelCache: _failingCache(),
          onTapReel: (reel) => tapped = reel,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Ichiran'));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'r1');
  });

  testWidgets('the table renders its headers and cells', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatTableBlockView(
          block: TableBlock(
            columns: ['SHOP', 'BROTH'],
            rows: [
              ['Ichiran', 'Tonkotsu'],
            ],
          ),
        ),
      ),
    );

    expect(find.text('SHOP'), findsOneWidget);
    expect(find.text('Tonkotsu'), findsOneWidget);
  });

  testWidgets('the chart renders a label per bar', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatChartBlockView(
          block: ChartBlock(
            title: 'WHAT YOU SAVE MOST',
            bars: [
              ChartBar(label: 'FOOD', value: 12, category: 'Food'),
              ChartBar(label: 'TRAVEL', value: 5, category: 'Travel'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('WHAT YOU SAVE MOST'), findsOneWidget);
    expect(find.text('FOOD'), findsOneWidget);
    expect(find.text('TRAVEL'), findsOneWidget);
  });

  testWidgets(
    'long bar labels stay inside their own slot instead of smearing into '
    'their neighbours',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const ChatChartBlockView(
            block: ChartBlock(
              title: 'WHAT YOU SAVE MOST',
              bars: [
                ChartBar(label: 'Scene', value: 4, category: 'Movies'),
                ChartBar(
                  label: 'Movie Recommendations',
                  value: 11,
                  category: 'Movies',
                ),
                ChartBar(label: 'Movie Spoilers', value: 6, category: 'Movies'),
                ChartBar(label: 'Trailers', value: 3, category: 'Movies'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final chartWidth = tester.getSize(find.byType(ChatChartBlockView)).width;
      final slotWidth = chartWidth / 4;

      for (final label in [
        'Scene',
        'Movie Recommendations',
        'Movie Spoilers',
        'Trailers',
      ]) {
        final width = tester.getSize(find.text(label)).width;
        expect(
          width,
          lessThanOrEqualTo(slotWidth + 0.5),
          reason: '"$label" overflowed its bar\'s slot',
        );
      }
    },
  );
}
