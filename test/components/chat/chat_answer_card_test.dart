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
}
