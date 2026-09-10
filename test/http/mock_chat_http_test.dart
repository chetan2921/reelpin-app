import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/mock_chat_http.dart';

Reel _reel(String id, String title, String category, String subCategory) {
  return Reel(
    id: id,
    userId: 'u1',
    url: 'https://example.com/$id',
    title: title,
    summary: '',
    caption: '',
    transcript: '',
    category: category,
    subCategory: subCategory,
    keyFacts: const [],
    locations: const [],
    peopleMentioned: const [],
    actionableItems: const [],
  );
}

void main() {
  test(
    'stages arrive before the answer, and the answer arrives last',
    () async {
      final http = MockChatHttp(
        reelsSource: () => [
          _reel('r1', 'Federer backhand', 'Sports', 'Tennis'),
        ],
        stageDelay: Duration.zero,
      );

      final events = await http
          .sendMessage(threadId: 't1', text: 'tennis')
          .toList();

      expect(events.length, greaterThan(1));
      expect(events.take(events.length - 1), everyElement(isA<StageEvent>()));
      expect(events.last, isA<AnswerEvent>());
    },
  );

  test('a question matching real saves cites those reels', () async {
    final http = MockChatHttp(
      reelsSource: () => [
        _reel('r1', 'Federer backhand', 'Sports', 'Tennis'),
        _reel('r2', 'Ichiran ramen', 'Food', 'Ramen'),
      ],
      stageDelay: Duration.zero,
    );

    final events = await http
        .sendMessage(threadId: 't1', text: 'what did I save about tennis?')
        .toList();
    final blocks = (events.last as AnswerEvent).blocks;
    final refs = blocks.whereType<ReelRefsBlock>().single;

    expect(refs.reelIds, ['r1']);
  });

  test('an empty library still answers, from the seeded fallback', () async {
    final http = MockChatHttp(
      reelsSource: () => const [],
      stageDelay: Duration.zero,
    );

    final events = await http
        .sendMessage(threadId: 't1', text: 'tokyo food')
        .toList();
    final blocks = (events.last as AnswerEvent).blocks;

    // The seed set demos every other block type…
    expect(blocks.whereType<TextBlock>(), isNotEmpty);
    expect(blocks.whereType<PlacesBlock>(), isNotEmpty);
    expect(blocks.whereType<TableBlock>(), isNotEmpty);
    expect(blocks.whereType<ChartBlock>(), isNotEmpty);
    // …but never ReelRefsBlock: seed ids don't exist in the user's own
    // library, so ChatReelStrip could never resolve them into cards.
    expect(blocks.whereType<ReelRefsBlock>(), isEmpty);
  });

  test(
    'a question matching nothing says so instead of citing at random',
    () async {
      final http = MockChatHttp(
        reelsSource: () => [_reel('r1', 'Ichiran ramen', 'Food', 'Ramen')],
        stageDelay: Duration.zero,
      );

      final events = await http
          .sendMessage(threadId: 't1', text: 'quantum chromodynamics')
          .toList();
      final blocks = (events.last as AnswerEvent).blocks;

      expect(blocks.whereType<ReelRefsBlock>(), isEmpty);
      expect(
        (blocks.whereType<TextBlock>().first).text.toLowerCase(),
        contains("couldn't find"),
      );
    },
  );

  test('fetchSuggestions returns nothing for an empty library', () async {
    final http = MockChatHttp(reelsSource: () => const []);

    expect(await http.fetchSuggestions(), isEmpty);
  });

  test('fetchSuggestions leads with the top category', () async {
    final http = MockChatHttp(
      reelsSource: () => [_reel('r1', 'Federer backhand', 'Sports', 'Tennis')],
    );

    final suggestions = await http.fetchSuggestions();

    expect(suggestions.first, 'What did I save about sports?');
  });
}
