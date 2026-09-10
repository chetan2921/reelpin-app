import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/services/chat/chat_thread_store.dart';
import 'package:reelpin/view_models/chat_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake whose stream stays open until the test explicitly resolves it, so
/// a thread switch can be driven while a request is still in flight.
class _ControllableChatHttp implements ChatHttp {
  final List<StreamController<ChatEvent>> controllers = [];
  final List<String> requestedThreadIds = [];

  int get calls => controllers.length;

  @override
  Future<List<String>> fetchSuggestions() async => const [];

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    List<ChatHistoryEntry> history = const [],
  }) {
    final controller = StreamController<ChatEvent>();
    controllers.add(controller);
    requestedThreadIds.add(threadId);
    return controller.stream;
  }

  void succeed(int callIndex, List<AnswerBlock> blocks) {
    controllers[callIndex].add(AnswerEvent(blocks));
    controllers[callIndex].close();
  }

  void fail(int callIndex, Object error) {
    controllers[callIndex].addError(error);
    controllers[callIndex].close();
  }
}

class _FakeChatHttp implements ChatHttp {
  _FakeChatHttp({this.shouldFail = false});

  final bool shouldFail;
  int calls = 0;
  final List<List<ChatHistoryEntry>> historyByCall = [];

  @override
  Future<List<String>> fetchSuggestions() async => const [];

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    List<ChatHistoryEntry> history = const [],
  }) async* {
    calls += 1;
    historyByCall.add(history);
    yield const StageEvent(
      ThinkingStage(label: 'SEARCHING', state: ThinkingStageState.active),
    );
    if (shouldFail) throw Exception('backend exploded');
    yield AnswerEvent([TextBlock('answer to $text')]);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ChatViewModel build(ChatHttp http) =>
      ChatViewModel(http, ChatThreadStore(), currentUserId: () => 'user-a');

  test('sending creates a thread titled from the first question', () async {
    final viewModel = build(_FakeChatHttp());

    await viewModel.send('what did I save about ramen?');

    expect(viewModel.threads, hasLength(1));
    expect(viewModel.activeThread!.title, 'what did I save about ramen?');
    expect(viewModel.activeThread!.messages, hasLength(2));
    expect(viewModel.activeThread!.messages.first.role, MessageRole.user);
    expect(
      (viewModel.activeThread!.messages.last.blocks.single as TextBlock).text,
      'answer to what did I save about ramen?',
    );
  });

  test('the first question carries no history, the second carries the first '
      'Q&A oldest-first', () async {
    final http = _FakeChatHttp();
    final viewModel = build(http);

    await viewModel.send('first question');
    await viewModel.send('second question');

    expect(http.historyByCall.first, isEmpty);
    expect(http.historyByCall.last.map((e) => e.role).toList(), [
      'user',
      'assistant',
    ]);
    expect(http.historyByCall.last.first.text, 'first question');
    expect(http.historyByCall.last.last.text, 'answer to first question');
  });

  test('an answer that never arrived is not history', () async {
    final http = _FakeChatHttp(shouldFail: true);
    final viewModel = build(http);

    await viewModel.send('doomed question');
    await viewModel.send('next question');

    // The question still counts as asked; the failed answer does not.
    expect(http.historyByCall.last.map((e) => e.role).toList(), ['user']);
    expect(http.historyByCall.last.single.text, 'doomed question');
  });

  test('history is capped at the last six messages', () async {
    final http = _FakeChatHttp();
    final viewModel = build(http);

    for (var i = 0; i < 5; i++) {
      await viewModel.send('question $i');
    }

    // The fifth question sees four completed pairs — eight entries — capped
    // to the last six, so question 0's turn falls off the front.
    expect(http.historyByCall.last, hasLength(6));
    expect(http.historyByCall.last.first.text, 'question 1');
    expect(http.historyByCall.last.last.text, 'answer to question 3');
  });

  test('stages are cleared once the answer lands', () async {
    final viewModel = build(_FakeChatHttp());

    await viewModel.send('tennis');

    expect(viewModel.stages, isEmpty);
    expect(viewModel.isAnswering, isFalse);
  });

  test('a failure marks the answer failed and keeps the question', () async {
    final viewModel = build(_FakeChatHttp(shouldFail: true));

    await viewModel.send('tennis');

    final messages = viewModel.activeThread!.messages;
    expect(messages.first.text, 'tennis');
    expect(messages.last.status, MessageStatus.failed);
    expect(viewModel.isAnswering, isFalse);
  });

  test(
    'retry re-sends the last question and replaces the failed answer',
    () async {
      final http = _FakeChatHttp();
      final viewModel = build(http);
      await viewModel.send('tennis');

      await viewModel.retryLast();

      expect(http.calls, 2);
      expect(viewModel.activeThread!.messages, hasLength(2));
      expect(
        viewModel.activeThread!.messages.last.status,
        MessageStatus.complete,
      );
    },
  );

  test('threads are persisted and come back on hydrate', () async {
    final viewModel = build(_FakeChatHttp());
    await viewModel.send('tennis');

    final restored = build(_FakeChatHttp());
    await restored.hydrate();

    expect(restored.threads.map((t) => t.title), ['tennis']);
  });

  test('hydrate downgrades a restored sending message to failed, so a request '
      'that was in flight when the app died does not come back as a dead '
      '"thinking" row', () async {
    final store = ChatThreadStore();
    final now = DateTime.now().toUtc();
    await store.save('user-a', [
      ChatThread(
        id: 't-stale',
        title: 'stale',
        createdAt: now,
        updatedAt: now,
        messages: [
          ChatMessage(
            id: 'm-u',
            role: MessageRole.user,
            text: 'stale question',
            createdAt: now,
          ),
          ChatMessage(
            id: 'm-a',
            role: MessageRole.assistant,
            createdAt: now,
            status: MessageStatus.sending,
          ),
        ],
      ),
    ]);

    final viewModel = build(_FakeChatHttp());
    await viewModel.hydrate();

    final restored = viewModel.threads.single.messages;
    expect(restored.first.status, MessageStatus.complete);
    expect(restored.last.status, MessageStatus.failed);
  });

  test('a new thread does not inherit the previous thread messages', () async {
    final viewModel = build(_FakeChatHttp());
    await viewModel.send('tennis');

    viewModel.startNewThread();

    expect(viewModel.activeThread, isNull);
    expect(viewModel.threads, hasLength(1));
  });

  test('an in-flight answer still lands on its own thread, on disk too, '
      'after the user switches away', () async {
    final http = _ControllableChatHttp();
    final viewModel = build(http);

    final pending = viewModel.send('ramen');
    final threadAId = viewModel.activeThread!.id;
    expect(viewModel.activeThread!.messages, hasLength(2));

    viewModel.startNewThread();
    expect(viewModel.activeThread, isNull);

    http.succeed(0, [TextBlock('ramen answer')]);
    await pending;

    final threadA = viewModel.threads.firstWhere((t) => t.id == threadAId);
    expect(threadA.messages.last.status, MessageStatus.complete);
    expect(
      (threadA.messages.last.blocks.single as TextBlock).text,
      'ramen answer',
    );

    final restored = build(_ControllableChatHttp());
    await restored.hydrate();
    final restoredThreadA = restored.threads.firstWhere(
      (t) => t.id == threadAId,
    );
    expect(restoredThreadA.messages.last.status, MessageStatus.complete);
  });

  test('an in-flight failure still lands on its own thread, on disk too, '
      'after the user switches away', () async {
    final http = _ControllableChatHttp();
    final viewModel = build(http);

    final pending = viewModel.send('ramen');
    final threadAId = viewModel.activeThread!.id;

    viewModel.startNewThread();

    http.fail(0, Exception('backend exploded'));
    await pending;

    final threadA = viewModel.threads.firstWhere((t) => t.id == threadAId);
    expect(threadA.messages.last.status, MessageStatus.failed);

    final restored = build(_ControllableChatHttp());
    await restored.hydrate();
    final restoredThreadA = restored.threads.firstWhere(
      (t) => t.id == threadAId,
    );
    expect(restoredThreadA.messages.last.status, MessageStatus.failed);
  });

  test(
    'sending into a different thread works while another thread is still '
    'answering, and a backgrounded stage never leaks into the active thread',
    () async {
      final http = _ControllableChatHttp();
      final viewModel = build(http);

      final pendingA = viewModel.send('ramen');
      final threadAId = viewModel.activeThread!.id;
      expect(viewModel.isAnswering, isTrue);

      viewModel.startNewThread();
      final pendingB = viewModel.send('sushi');

      expect(viewModel.threads, hasLength(2));
      expect(viewModel.activeThread!.id, isNot(threadAId));
      expect(viewModel.activeThread!.messages, hasLength(2));
      expect(http.calls, 2);

      // A stage line belonging to the backgrounded thread A must not paint
      // itself onto thread B, which is what the user is looking at now.
      http.controllers[0].add(
        const StageEvent(
          ThinkingStage(label: 'SEARCHING', state: ThinkingStageState.active),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.stages, isEmpty);

      http.succeed(0, [TextBlock('ramen answer')]);
      http.succeed(1, [TextBlock('sushi answer')]);
      await pendingA;
      await pendingB;

      final threadA = viewModel.threads.firstWhere((t) => t.id == threadAId);
      expect(threadA.messages.last.status, MessageStatus.complete);
      expect(
        viewModel.activeThread!.messages.last.status,
        MessageStatus.complete,
      );
    },
  );

  test(
    'a second send on the same thread while it is answering is ignored',
    () async {
      final http = _ControllableChatHttp();
      final viewModel = build(http);

      final pendingA = viewModel.send('ramen');
      final threadAId = viewModel.activeThread!.id;
      expect(viewModel.activeThread!.messages, hasLength(2));

      await viewModel.send('ramen again');

      expect(http.calls, 1);
      expect(viewModel.activeThread!.id, threadAId);
      expect(viewModel.activeThread!.messages, hasLength(2));

      http.succeed(0, [TextBlock('answer')]);
      await pendingA;
    },
  );
}
