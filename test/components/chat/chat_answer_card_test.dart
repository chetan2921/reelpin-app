import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_answer_card.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';

ChatReelCache _reelCache() =>
    ChatReelCache((_) async => throw Exception('not found'));

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

ChatMessage _answer({
  List<AnswerBlock> blocks = const [],
  MessageStatus status = MessageStatus.complete,
}) => ChatMessage(
  id: 'm1',
  role: MessageRole.assistant,
  createdAt: DateTime.utc(2026, 9, 5),
  blocks: blocks,
  status: status,
);

void main() {
  testWidgets('renders text blocks', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatAnswerCard(
          message: _answer(blocks: const [TextBlock('You saved 12 reels.')]),
          onRetry: () {},
          library: const [],
          reelCache: _reelCache(),
          onTapReel: (_) {},
          onSaveToCollection: () {},
        ),
      ),
    );

    expect(find.text('You saved 12 reels.'), findsOneWidget);
  });

  testWidgets('a failed answer offers retry and calls back', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _host(
        ChatAnswerCard(
          message: _answer(status: MessageStatus.failed),
          onRetry: () => retried += 1,
          library: const [],
          reelCache: _reelCache(),
          onTapReel: (_) {},
          onSaveToCollection: () {},
        ),
      ),
    );

    await tester.tap(find.text('RETRY'));
    expect(retried, 1);
  });

  testWidgets('a spent allowance offers Pro and retry', (tester) async {
    var upgraded = 0;
    var retried = 0;
    await tester.pumpWidget(
      _host(
        ChatAnswerCard(
          message: _answer(status: MessageStatus.limitReached),
          onRetry: () => retried += 1,
          onUpgrade: () => upgraded += 1,
          library: const [],
          reelCache: _reelCache(),
          onTapReel: (_) {},
          onSaveToCollection: () {},
        ),
      ),
    );

    expect(find.text("You've used today's free AI messages."), findsOneWidget);
    expect(find.text("That didn't go through."), findsNothing);
    await tester.tap(find.text('GET PRO'));
    await tester.tap(find.text('RETRY'));
    expect((upgraded, retried), (1, 1));
  });

  testWidgets('without an upgrade callback there is no GET PRO', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatAnswerCard(
          message: _answer(status: MessageStatus.limitReached),
          onRetry: null,
          library: const [],
          reelCache: _reelCache(),
          onTapReel: (_) {},
          onSaveToCollection: () {},
        ),
      ),
    );

    expect(find.text("You've used today's free AI messages."), findsOneWidget);
    expect(find.text('GET PRO'), findsNothing);
    expect(find.text('RETRY'), findsNothing);
  });

  testWidgets('a spent Pro cap says when it resets and offers no Pro', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      _host(
        ChatAnswerCard(
          message: _answer(status: MessageStatus.capReached),
          onRetry: () => retried += 1,
          onUpgrade: () {},
          library: const [],
          reelCache: _reelCache(),
          onTapReel: (_) {},
          onSaveToCollection: () {},
        ),
      ),
    );

    expect(
      find.text(
        "You've reached today's chat limit. It resets at midnight IST.",
      ),
      findsOneWidget,
    );
    expect(find.text('GET PRO'), findsNothing);
    await tester.tap(find.text('RETRY'));
    expect(retried, 1);
  });

  testWidgets('renders suggestions blocks', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatAnswerCard(
          message: _answer(
            blocks: const [
              SuggestionsBlock(
                title: 'PICKED FOR YOUR TASTE',
                items: [
                  Suggestion(
                    title: 'Watch the Laver Cup',
                    kind: 'event',
                    why: 'You save a lot of tennis.',
                  ),
                ],
              ),
            ],
          ),
          onRetry: () {},
          library: const [],
          reelCache: _reelCache(),
          onTapReel: (_) {},
          onSaveToCollection: () {},
        ),
      ),
    );

    expect(find.text('PICKED FOR YOUR TASTE'), findsOneWidget);
    expect(find.text('Watch the Laver Cup'), findsOneWidget);
  });
}
