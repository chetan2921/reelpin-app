import 'dart:async';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/data_models/chat/collection_chat_thread.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';

/// In-memory collection chats, for working on the shared-chat UI without the
/// backend (`--dart-define=MOCK_CHAT=true`).
///
/// State lives for the life of the process — long enough to watch a thread
/// grow, short enough that nothing here is mistaken for storage.
class MockCollectionChatHttp implements CollectionChatHttp {
  MockCollectionChatHttp({
    Duration stageDelay = const Duration(milliseconds: 650),
    String authorName = 'You',
  }) : _stageDelay = stageDelay,
       _authorName = authorName;

  final Duration _stageDelay;
  final String _authorName;

  /// collection id → thread id → messages, oldest first.
  final Map<String, Map<String, List<ChatMessage>>> _collections = {};

  List<ChatMessage> _thread(String collectionId, String threadId) =>
      (_collections[collectionId] ??= {})[threadId] ??= [];

  @override
  Future<List<CollectionChatThread>> fetchThreads(String collectionId) async {
    final threads = [
      for (final entry in (_collections[collectionId] ?? const {}).entries)
        if (entry.value.isNotEmpty)
          CollectionChatThread(
            id: entry.key,
            title: _titleOf(entry.value),
            questionCount: entry.value
                .where((m) => m.role == MessageRole.user)
                .length,
            updatedAt: entry.value.last.createdAt,
          ),
    ];
    threads.sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
    return threads;
  }

  /// The same titling the backend does: the first question, or for a thread a
  /// shared answer started, that answer's opening line.
  static String _titleOf(List<ChatMessage> thread) {
    for (final message in thread) {
      if (message.role == MessageRole.user && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
      if (message.role == MessageRole.assistant) {
        final opening = message.blocks.whereType<TextBlock>().firstOrNull;
        if (opening != null && opening.text.trim().isNotEmpty) {
          return opening.text.trim().split('\n').first;
        }
      }
    }
    return 'Untitled chat';
  }

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    required String threadId,
    String? after,
  }) async {
    final thread = _thread(collectionId, threadId);
    if (after == null) return CollectionChatPage(messages: List.of(thread));
    final index = thread.indexWhere((m) => m.id == after);
    // An unknown id means the caller is holding something this thread no
    // longer has. Returning everything is the recoverable answer; returning
    // nothing would leave the screen frozen on a stale thread.
    if (index == -1) return CollectionChatPage(messages: List.of(thread));
    return CollectionChatPage(messages: thread.sublist(index + 1));
  }

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
  }) async* {
    for (final label in const ['READING THIS COLLECTION', 'THINKING']) {
      yield StageEvent(
        ThinkingStage(label: label, state: ThinkingStageState.active),
      );
      await Future<void>.delayed(_stageDelay);
      yield StageEvent(
        ThinkingStage(label: label, state: ThinkingStageState.done),
      );
    }

    final blocks = <AnswerBlock>[
      TextBlock('Here is what this collection says about "$text".'),
    ];
    _append(
      collectionId,
      threadId,
      question: text,
      attachments: attachments,
      blocks: blocks,
      isShared: false,
    );
    yield AnswerEvent(blocks);
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String threadId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async {
    _append(
      collectionId,
      threadId,
      question: questionText,
      blocks: blocks,
      isShared: true,
    );
  }

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) async {
    for (final thread in (_collections[collectionId] ?? const {}).values) {
      thread.removeWhere((m) => m.id == messageId);
    }
  }

  void _append(
    String collectionId,
    String threadId, {
    required String question,
    required List<AnswerBlock> blocks,
    required bool isShared,
    List<ChatAttachment> attachments = const [],
  }) {
    final now = DateTime.now().toUtc();
    final stamp = now.microsecondsSinceEpoch;
    _thread(collectionId, threadId).addAll([
      ChatMessage(
        id: 'cm-$stamp-u',
        role: MessageRole.user,
        text: question,
        attachments: attachments,
        authorName: _authorName,
        isShared: isShared,
        createdAt: now,
      ),
      ChatMessage(
        id: 'cm-$stamp-a',
        role: MessageRole.assistant,
        blocks: blocks,
        isShared: isShared,
        createdAt: now,
      ),
    ]);
  }
}
