import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/mock_collection_chat_http.dart';

void main() {
  MockCollectionChatHttp build() =>
      MockCollectionChatHttp(stageDelay: Duration.zero);

  test('an ask emits stages then one answer, and persists the pair', () async {
    final http = build();

    final events = await http
        .ask(collectionId: 'c1', text: 'what next?')
        .toList();

    expect(events.whereType<StageEvent>(), isNotEmpty);
    expect(events.whereType<AnswerEvent>(), hasLength(1));

    final page = await http.fetchMessages('c1');
    expect(page.messages.map((m) => m.role).toList(), [
      MessageRole.user,
      MessageRole.assistant,
    ]);
    expect(page.messages.first.text, 'what next?');
    expect(page.messages.last.blocks, isNotEmpty);
  });

  test('after returns only what is newer', () async {
    final http = build();
    await http.ask(collectionId: 'c1', text: 'first').toList();
    final firstPage = await http.fetchMessages('c1');

    await http.ask(collectionId: 'c1', text: 'second').toList();
    final tail = await http.fetchMessages(
      'c1',
      after: firstPage.messages.last.id,
    );

    expect(tail.messages.map((m) => m.text), contains('second'));
    expect(tail.messages.map((m) => m.text), isNot(contains('first')));
  });

  test(
    'an unknown after id returns the whole thread rather than nothing',
    () async {
      final http = build();
      await http.ask(collectionId: 'c1', text: 'first').toList();

      final page = await http.fetchMessages('c1', after: 'no-such-id');

      expect(page.messages, hasLength(2));
    },
  );

  test('a shared answer is stored verbatim and flagged', () async {
    final http = build();

    await http.shareAnswer(
      collectionId: 'c1',
      questionText: 'asked privately',
      blocks: const [TextBlock('the answer')],
    );

    final page = await http.fetchMessages('c1');
    expect(page.messages.first.text, 'asked privately');
    expect(page.messages.last.isShared, isTrue);
    expect((page.messages.last.blocks.single as TextBlock).text, 'the answer');
  });

  test('a live ask is not flagged as shared', () async {
    final http = build();
    await http.ask(collectionId: 'c1', text: 'asked here').toList();

    final page = await http.fetchMessages('c1');
    expect(page.messages.every((m) => !m.isShared), isTrue);
  });

  test('collections do not share a thread', () async {
    final http = build();
    await http.ask(collectionId: 'c1', text: 'only in c1').toList();

    expect((await http.fetchMessages('c2')).messages, isEmpty);
  });

  test('deleting removes just that message', () async {
    final http = build();
    await http.ask(collectionId: 'c1', text: 'q').toList();
    final page = await http.fetchMessages('c1');

    await http.deleteMessage(
      collectionId: 'c1',
      messageId: page.messages.first.id,
    );

    final after = await http.fetchMessages('c1');
    expect(after.messages, hasLength(1));
    expect(after.messages.single.role, MessageRole.assistant);
  });
}
