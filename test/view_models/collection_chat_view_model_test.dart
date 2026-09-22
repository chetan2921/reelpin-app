import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/data_models/chat/collection_chat_thread.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';
import 'package:reelpin/http/mock_collection_chat_http.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/view_models/collection_chat_view_model.dart';

/// Loads fine but every write throws, so the failure path can be driven
/// without a real backend.
class _FailingCollectionChatHttp implements CollectionChatHttp {
  @override
  Future<List<CollectionChatThread>> fetchThreads(String collectionId) async =>
      const [];

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    required String threadId,
    String? after,
  }) async => const CollectionChatPage();

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
  }) async* {
    throw Exception('backend exploded');
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String threadId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async => throw Exception('backend exploded');

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) async => throw Exception('backend exploded');
}

/// Holds the thread list back until [release], so a test can look at what
/// the screen shows before the network has answered.
class _SlowThreadsHttp implements CollectionChatHttp {
  _SlowThreadsHttp(this._inner);

  final CollectionChatHttp _inner;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<List<CollectionChatThread>> fetchThreads(String collectionId) async {
    await _gate.future;
    return _inner.fetchThreads(collectionId);
  }

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    required String threadId,
    String? after,
  }) => _inner.fetchMessages(collectionId, threadId: threadId, after: after);

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
  }) => _inner.ask(
    collectionId: collectionId,
    threadId: threadId,
    text: text,
    attachments: attachments,
  );

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String threadId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) => _inner.shareAnswer(
    collectionId: collectionId,
    threadId: threadId,
    questionText: questionText,
    blocks: blocks,
  );

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) => _inner.deleteMessage(collectionId: collectionId, messageId: messageId);
}

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('collection_chat_vm');
  });

  tearDown(() {
    if (!directory.existsSync()) return;
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // A cache write can still be landing a file here as the test ends;
      // the OS temp directory is cleaned up regardless.
    }
  });

  ContentCache cache() => ContentCache.forTesting(
    directory: directory,
    userIdProvider: () => 'user-a',
  );

  MockCollectionChatHttp mock() =>
      MockCollectionChatHttp(stageDelay: Duration.zero);

  CollectionChatViewModel viewModelFor(CollectionChatHttp http) =>
      CollectionChatViewModel(http, 'c1', cache: cache());

  test('load opens the most recently active conversation', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'older').toList();
    await http.ask(collectionId: 'c1', threadId: 't-2', text: 'newer').toList();
    final viewModel = viewModelFor(http);
    expect(viewModel.hasLoaded, isFalse);

    await viewModel.load();

    expect(viewModel.activeThreadId, 't-2');
    expect(viewModel.messages.first.text, 'newer');
    expect(viewModel.threads.map((t) => t.id), ['t-2', 't-1']);
    expect(viewModel.hasLoaded, isTrue);
    expect(viewModel.isLoading, isFalse);
  });

  test(
    'a collection with no chats opens on a new, empty conversation',
    () async {
      final viewModel = viewModelFor(mock());

      await viewModel.load();

      expect(viewModel.activeThreadId, isNull);
      expect(viewModel.messages, isEmpty);
      expect(viewModel.hasLoaded, isTrue);
    },
  );

  test('asking in a new conversation starts a thread for it', () async {
    final viewModel = viewModelFor(mock());
    await viewModel.load();

    final pending = viewModel.ask('what next?');
    expect(viewModel.messages.first.text, 'what next?');
    expect(viewModel.isAsking, isTrue);

    await pending;

    expect(viewModel.isAsking, isFalse);
    expect(viewModel.activeThreadId, isNotNull);
    // The optimistic pair is replaced by the server's, not duplicated.
    expect(viewModel.messages, hasLength(2));
    expect(viewModel.threads.single.title, 'what next?');
  });

  test('a new chat leaves the old conversation in the sidebar', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'first').toList();
    final viewModel = viewModelFor(http);
    await viewModel.load();

    viewModel.startNewThread();
    expect(viewModel.activeThreadId, isNull);
    expect(viewModel.messages, isEmpty);

    await viewModel.ask('second');

    expect(viewModel.threads, hasLength(2));
    expect(viewModel.messages.first.text, 'second');
  });

  test('opening a thread from the sidebar switches to it', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'older').toList();
    await http.ask(collectionId: 'c1', threadId: 't-2', text: 'newer').toList();
    final viewModel = viewModelFor(http);
    await viewModel.load();

    viewModel.openThread('t-1');
    await pumpEventQueue();

    expect(viewModel.activeThreadId, 't-1');
    expect(viewModel.messages.first.text, 'older');
  });

  test('attachments ride along with the question', () async {
    final viewModel = viewModelFor(mock());
    await viewModel.load();

    await viewModel.ask(
      'compare',
      attachments: const [
        ChatAttachment(
          kind: AttachmentKind.link,
          displayName: 'example.com',
          url: 'https://example.com',
        ),
      ],
    );

    expect(
      viewModel.messages.first.attachments.single.url,
      'https://example.com',
    );
  });

  test('a failed ask surfaces an error and leaves the answer failed', () async {
    final viewModel = viewModelFor(_FailingCollectionChatHttp());
    await viewModel.load();

    await viewModel.ask('doomed');

    expect(viewModel.error, isNotNull);
    expect(viewModel.isAsking, isFalse);
    expect(viewModel.messages.last.status, MessageStatus.failed);
    expect(viewModel.messages.first.text, 'doomed');
  });

  test('an empty question does nothing', () async {
    final viewModel = viewModelFor(mock());

    await viewModel.ask('   ');

    expect(viewModel.messages, isEmpty);
  });

  test(
    'a poll picks up what another editor asked in the open thread',
    () async {
      final http = mock();
      await http
          .ask(collectionId: 'c1', threadId: 't-1', text: 'first')
          .toList();
      final viewModel = viewModelFor(http);
      await viewModel.load();
      await http
          .ask(collectionId: 'c1', threadId: 't-1', text: 'from another editor')
          .toList();

      await viewModel.pollOnce();

      expect(
        viewModel.messages.map((m) => m.text),
        contains('from another editor'),
      );
      expect(viewModel.messages, hasLength(4));
    },
  );

  test('a poll adds a thread someone else started to the sidebar', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', threadId: 't-1', text: 'first').toList();
    final viewModel = viewModelFor(http);
    await viewModel.load();
    await http
        .ask(collectionId: 'c1', threadId: 't-9', text: 'new topic')
        .toList();

    await viewModel.pollOnce();

    expect(viewModel.threads.map((t) => t.id), contains('t-9'));
    // The open conversation is left where the user is.
    expect(viewModel.activeThreadId, 't-1');
  });

  test(
    'reopening paints the cached conversation before the network answers',
    () async {
      final http = mock();
      await http
          .ask(collectionId: 'c1', threadId: 't-1', text: 'cached question')
          .toList();
      final first = viewModelFor(http);
      await first.load();
      // The cache is written behind the load; wait for it to land.
      for (var i = 0; i < 200; i++) {
        if (await cache().read('collection_chat_c1_t-1') != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      first.dispose();

      final slow = _SlowThreadsHttp(http);
      final second = viewModelFor(slow);
      unawaited(second.load());
      for (var i = 0; i < 200 && second.messages.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(second.messages.first.text, 'cached question');
      expect(second.hasLoaded, isTrue);
      slow.release();
    },
  );
}
