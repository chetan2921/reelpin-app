import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_thinking_stages.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'a sending message with zero stages still renders a placeholder row',
    (tester) async {
      await tester.pumpWidget(_host(const ChatThinkingStages(stages: [])));

      // Proves the send-to-first-event gap never renders as an empty Column:
      // there is real, non-zero content on screen before any stage arrives.
      expect(find.byType(ChatThinkingStages), findsOneWidget);
      expect(
        tester.getSize(find.byType(ChatThinkingStages)).height,
        greaterThan(0),
      );
      expect(find.text('THINKING'), findsOneWidget);
    },
  );

  testWidgets('real stages render in place of the placeholder', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatThinkingStages(
          stages: [
            ThinkingStage(label: 'SEARCHING', state: ThinkingStageState.done),
          ],
        ),
      ),
    );

    expect(find.text('THINKING'), findsNothing);
    expect(find.text('SEARCHING'), findsOneWidget);
  });
}
