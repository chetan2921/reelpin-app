import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_answer_actions.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';

ChatMessage _answer(List<AnswerBlock> blocks) => ChatMessage(
  id: 'm1',
  role: MessageRole.assistant,
  createdAt: DateTime.utc(2026, 9, 5),
  blocks: blocks,
);

void main() {
  test('plain text flattens text and tables, and skips reel refs', () {
    final text = answerPlainText(
      _answer(const [
        TextBlock('You saved three ramen places.'),
        ReelRefsBlock(['r1']),
        TableBlock(
          columns: ['SHOP', 'BROTH'],
          rows: [
            ['Ichiran', 'Tonkotsu'],
          ],
        ),
      ]),
    );

    expect(text, contains('You saved three ramen places.'));
    expect(text, contains('SHOP\tBROTH'));
    expect(text, contains('Ichiran\tTonkotsu'));
    expect(text, isNot(contains('r1')));
  });

  testWidgets('export destinations render disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAnswerActions(
            message: _answer(const [TextBlock('hi')]),
            onSaveToCollection: () {},
          ),
        ),
      ),
    );

    expect(find.text('NOTION'), findsOneWidget);
    expect(find.text('CALENDAR'), findsOneWidget);
    expect(find.text('SLACK'), findsOneWidget);
  });

  testWidgets(
    'collection chip is offered even when the answer cites no reels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAnswerActions(
              message: _answer(const [TextBlock('hi')]),
              onSaveToCollection: () {},
            ),
          ),
        ),
      );

      // What goes into the collection's chat is the answer itself, so a
      // text-only answer can be added as readily as one that cites reels.
      expect(find.text('+ COLLECTION'), findsOneWidget);
    },
  );

  testWidgets('save to collection calls back', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAnswerActions(
            message: _answer(const [
              TextBlock('hi'),
              ReelRefsBlock(['r1']),
            ]),
            onSaveToCollection: () => saved += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('+ COLLECTION'));
    expect(saved, 1);
  });
}
