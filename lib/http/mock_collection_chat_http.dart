import 'dart:async';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';

/// In-memory collection threads, for working on the shared-chat UI without the
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
  final Map<String, List<ChatMessage>> _threads = {};

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    String? after,
  }) async {
    final thread = _threads[collectionId] ?? const <ChatMessage>[];
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
    required String text,
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
    _append(collectionId, question: text, blocks: blocks, isShared: false);
    yield AnswerEvent(blocks);
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async {
    _append(
      collectionId,
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
    _threads[collectionId]?.removeWhere((m) => m.id == messageId);
  }

  void _append(
    String collectionId, {
    required String question,
    required List<AnswerBlock> blocks,
    required bool isShared,
  }) {
    final now = DateTime.now().toUtc();
    final stamp = now.microsecondsSinceEpoch;
    (_threads[collectionId] ??= []).addAll([
      ChatMessage(
        id: 'cm-$stamp-u',
        role: MessageRole.user,
        text: question,
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
