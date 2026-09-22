import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/mock_collection_chat_http.dart';

void main() {
  MockCollectionChatHttp build() =>
      MockCollectionChatHttp(stageDelay: Duration.zero);

  test(
    'an ask emits stages then one answer, and keeps the pair in its thread',
    () async {
      final http = build();

      final events = await http
          .ask(collectionId: 'c1', threadId: 't-1', text: 'what next?')
          .toList();

      expect(events.whereType<StageEvent>(), isNotEmpty);
      expect(events.whereType<AnswerEvent>(), hasLength(1));

      final page = await http.fetchMessages('c1', threadId: 't-1');
      expect(page.messages.map((m) => m.role).toList(), [
        MessageRole.user,
        MessageRole.assistant,
      ]);
      expect(page.messages.first.text, 'what next?');
    },
  );

  test('threads inside one collection do not see each other', () async {
    final http = build();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'first').toList();
    await http
        .ask(collectionId: 'c1', threadId: 't-2', text: 'second')
        .toList();

    final first = await http.fetchMessages('c1', threadId: 't-1');

    expect(first.messages.map((m) => m.text), isNot(contains('second')));
  });

  test(
    'the sidebar lists threads newest first, titled by the first question',
    () async {
      final http = build();
      await http
          .ask(collectionId: 'c1', threadId: 't-1', text: 'first question')
          .toList();
      await http
          .ask(collectionId: 'c1', threadId: 't-2', text: 'second question')
          .toList();

      final threads = await http.fetchThreads('c1');

      expect(threads.map((t) => t.id), ['t-2', 't-1']);
      expect(threads.last.title, 'first question');
      expect(threads.last.questionCount, 1);
    },
  );

  test(
    'a thread started by a shared answer is titled by that answer',
    () async {
      final http = build();
      await http.shareAnswer(
        collectionId: 'c1',
        threadId: 's-1',
        questionText: '',
        blocks: const [TextBlock('Start with the ramen.\nMore detail')],
      );

      final threads = await http.fetchThreads('c1');

      expect(threads.single.title, 'Start with the ramen.');
    },
  );

  test('after returns only what is newer', () async {
    final http = build();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'first').toList();
    final firstPage = await http.fetchMessages('c1', threadId: 't-1');

    await http
        .ask(collectionId: 'c1', threadId: 't-1', text: 'second')
        .toList();
    final tail = await http.fetchMessages(
      'c1',
      threadId: 't-1',
      after: firstPage.messages.last.id,
    );

    expect(tail.messages.map((m) => m.text), contains('second'));
    expect(tail.messages.map((m) => m.text), isNot(contains('first')));
  });

  test(
    'an unknown after id returns the whole thread rather than nothing',
    () async {
      final http = build();
      await http
          .ask(collectionId: 'c1', threadId: 't-1', text: 'first')
          .toList();

      final page = await http.fetchMessages(
        'c1',
        threadId: 't-1',
        after: 'no-such-id',
      );

      expect(page.messages, hasLength(2));
    },
  );

  test('a shared answer is stored verbatim and flagged', () async {
    final http = build();

    await http.shareAnswer(
      collectionId: 'c1',
      threadId: 's-1',
      questionText: '',
      blocks: const [TextBlock('the answer')],
    );

    final page = await http.fetchMessages('c1', threadId: 's-1');
    expect(page.messages.last.isShared, isTrue);
    expect((page.messages.last.blocks.single as TextBlock).text, 'the answer');
  });

  test('an ask keeps its attachments on the question', () async {
    final http = build();

    await http
        .ask(
          collectionId: 'c1',
          threadId: 't-1',
          text: 'compare',
          attachments: const [
            ChatAttachment(
              kind: AttachmentKind.link,
              displayName: 'example.com',
              url: 'https://example.com',
            ),
          ],
        )
        .toList();

    final page = await http.fetchMessages('c1', threadId: 't-1');
    expect(page.messages.first.attachments.single.url, 'https://example.com');
  });

  test('collections do not share threads', () async {
    final http = build();
    await http
        .ask(collectionId: 'c1', threadId: 't-1', text: 'only in c1')
        .toList();

    expect(await http.fetchThreads('c2'), isEmpty);
    expect((await http.fetchMessages('c2', threadId: 't-1')).messages, isEmpty);
  });

  test('deleting removes just that message', () async {
    final http = build();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'q').toList();
    final page = await http.fetchMessages('c1', threadId: 't-1');

    await http.deleteMessage(
      collectionId: 'c1',
      messageId: page.messages.first.id,
    );

    final after = await http.fetchMessages('c1', threadId: 't-1');
    expect(after.messages, hasLength(1));
    expect(after.messages.single.role, MessageRole.assistant);
  });
}
