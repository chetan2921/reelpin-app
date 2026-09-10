import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_reel_strip.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 400, child: child)),
);

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
  testWidgets(
    'a cited id missing from the library is fetched and its card appears',
    (tester) async {
      final completer = Completer<Reel>();
      final cache = ChatReelCache((id) => completer.future);

      await tester.pumpWidget(
        _host(
          ChatReelStrip(
            reelIds: const ['missing'],
            library: const [],
            reelCache: cache,
            onTapReel: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Nothing resolved yet — the fetch is still in flight.
      expect(find.text('Fetched Title'), findsNothing);

      completer.complete(_reel('missing', 'Fetched Title'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Fetched Title'), findsOneWidget);
    },
  );

  testWidgets(
    'an id that fails to fetch is dropped without breaking the others',
    (tester) async {
      final cache = ChatReelCache((id) async {
        if (id == 'gone') throw Exception('404');
        return _reel(id, 'Ichiran');
      });

      await tester.pumpWidget(
        _host(
          ChatReelStrip(
            reelIds: const ['r1', 'gone'],
            library: const [],
            reelCache: cache,
            onTapReel: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Ichiran'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a card already in the cache is never fetched', (tester) async {
    var calls = 0;
    final cache = ChatReelCache((id) async {
      calls += 1;
      return _reel(id, 'Ichiran');
    });
    // Pre-populate the cache the way an earlier strip / thread would have.
    await cache.resolve('r1');
    expect(calls, 1);

    await tester.pumpWidget(
      _host(
        ChatReelStrip(
          reelIds: const ['r1'],
          library: const [],
          reelCache: cache,
          onTapReel: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Ichiran'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('a card already in the local library is never fetched', (
    tester,
  ) async {
    var calls = 0;
    final cache = ChatReelCache((id) async {
      calls += 1;
      return _reel(id, 'should not be used');
    });

    await tester.pumpWidget(
      _host(
        ChatReelStrip(
          reelIds: const ['r1'],
          library: [_reel('r1', 'Ichiran')],
          reelCache: cache,
          onTapReel: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Ichiran'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'a rebuild with the same cited ids but a new library list instance '
    'issues no new fetches',
    (tester) async {
      var calls = 0;
      final cache = ChatReelCache((id) async {
        calls += 1;
        return _reel(id, 'Ichiran');
      });

      Widget build(List<Reel> library) => _host(
        ChatReelStrip(
          reelIds: const ['missing'],
          library: library,
          reelCache: cache,
          onTapReel: (_) {},
        ),
      );

      // Library starts empty, so 'missing' is fetched once.
      await tester.pumpWidget(build(const []));
      await tester.pump();
      await tester.pump();
      expect(calls, 1);

      // Same library content, but `ReelRepository.cachedReels` hands back a
      // fresh `List.unmodifiable` on every read — simulate that with a
      // brand-new (still-empty) list instance and confirm no re-fetch.
      await tester.pumpWidget(build(List<Reel>.of(const [])));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ichiran'), findsOneWidget);
      expect(calls, 1);
    },
  );
}
