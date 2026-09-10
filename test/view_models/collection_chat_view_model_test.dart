import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';
import 'package:reelpin/http/mock_collection_chat_http.dart';
import 'package:reelpin/view_models/collection_chat_view_model.dart';

/// Every call throws, so the failure path can be driven without a real
/// backend.
class _FailingCollectionChatHttp implements CollectionChatHttp {
  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    String? after,
  }) async => const CollectionChatPage();

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String text,
  }) async* {
    throw Exception('backend exploded');
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async => throw Exception('backend exploded');

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) async => throw Exception('backend exploded');
}

void main() {
  MockCollectionChatHttp mock() =>
      MockCollectionChatHttp(stageDelay: Duration.zero);

  test('load fills the thread', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', text: 'seeded').toList();
    final viewModel = CollectionChatViewModel(http, 'c1');
    expect(viewModel.hasLoaded, isFalse);

    await viewModel.load();

    expect(viewModel.messages, hasLength(2));
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.hasLoaded, isTrue);
    expect(viewModel.error, isNull);
  });

  test('ask shows the question immediately, then the server thread', () async {
    final http = mock();
    final viewModel = CollectionChatViewModel(http, 'c1');
    await viewModel.load();

    final pending = viewModel.ask('what next?');
    expect(viewModel.messages.first.text, 'what next?');
    expect(viewModel.isAsking, isTrue);

    await pending;

    expect(viewModel.isAsking, isFalse);
    // The optimistic pair is replaced by the server's, not duplicated.
    expect(viewModel.messages, hasLength(2));
    expect(viewModel.messages.last.blocks, isNotEmpty);
    expect(viewModel.stages, isEmpty);
  });

  test('a failed ask surfaces an error and leaves the answer failed', () async {
    final viewModel = CollectionChatViewModel(
      _FailingCollectionChatHttp(),
      'c1',
    );

    await viewModel.ask('doomed');

    expect(viewModel.error, isNotNull);
    expect(viewModel.isAsking, isFalse);
    expect(viewModel.messages.last.status, MessageStatus.failed);
    expect(viewModel.messages.first.text, 'doomed');
  });

  test('an empty question does nothing', () async {
    final http = mock();
    final viewModel = CollectionChatViewModel(http, 'c1');

    await viewModel.ask('   ');

    expect(viewModel.messages, isEmpty);
  });

  test('a poll picks up what another editor asked', () async {
    final http = mock();
    final viewModel = CollectionChatViewModel(http, 'c1');
    await viewModel.load();
    await http.ask(collectionId: 'c1', text: 'from another editor').toList();

    await viewModel.pollOnce();

    expect(
      viewModel.messages.map((m) => m.text),
      contains('from another editor'),
    );
    expect(viewModel.messages, hasLength(2));
  });

  test('a poll that finds nothing new leaves the thread alone', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', text: 'seeded').toList();
    final viewModel = CollectionChatViewModel(http, 'c1');
    await viewModel.load();

    await viewModel.pollOnce();

    expect(viewModel.messages, hasLength(2));
  });

  test('a failed poll is silent and leaves the thread intact', () async {
    final http = mock();
    await http.ask(collectionId: 'c1', text: 'seeded').toList();
    final viewModel = CollectionChatViewModel(http, 'c1');
    await viewModel.load();

    await CollectionChatViewModel(
      _FailingCollectionChatHttp(),
      'c1',
    ).pollOnce();

    expect(viewModel.messages, hasLength(2));
    expect(viewModel.error, isNull);
  });
}
