import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';

void main() {
  test('parses a page of collection messages', () {
    final page = CollectionChatPage.fromJson({
      'messages': [
        {
          'id': 'm1',
          'role': 'user',
          'author_name': 'Priya',
          'text': 'what should we cook first?',
          'created_at': '2026-09-10T10:00:00Z',
        },
        {
          'id': 'm2',
          'role': 'assistant',
          'source': 'shared',
          'blocks': [
            {'type': 'text', 'text': 'Start with the ramen.'},
          ],
          'created_at': '2026-09-10T10:00:05Z',
        },
      ],
    });

    expect(page.messages, hasLength(2));
    expect(page.messages.first.role, MessageRole.user);
    expect(page.messages.first.authorName, 'Priya');
    expect(page.messages.first.isShared, isFalse);
    expect(page.messages.last.isShared, isTrue);
    expect(
      (page.messages.last.blocks.single as TextBlock).text,
      'Start with the ramen.',
    );
  });

  test('a malformed messages field yields an empty page, not a throw', () {
    expect(CollectionChatPage.fromJson({'messages': 'nope'}).messages, isEmpty);
    expect(CollectionChatPage.fromJson(const {}).messages, isEmpty);
  });

  test('a private message carries neither an author nor a shared flag', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'user',
      'text': 'just me',
      'created_at': '2026-09-10T10:00:00Z',
    });

    expect(message.authorName, isEmpty);
    expect(message.isShared, isFalse);
  });

  test('copyWith keeps the author and the shared flag', () {
    final message = ChatMessage(
      id: 'm1',
      role: MessageRole.assistant,
      authorName: 'Priya',
      isShared: true,
      createdAt: DateTime.utc(2026, 9, 10),
    );

    expect(message.copyWith(status: MessageStatus.failed).authorName, 'Priya');
    expect(message.copyWith(status: MessageStatus.failed).isShared, isTrue);
  });
}
