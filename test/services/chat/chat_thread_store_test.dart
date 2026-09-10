import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/services/chat/chat_thread_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChatThread _thread(String id) => ChatThread(
  id: id,
  title: 'Thread $id',
  createdAt: DateTime.utc(2026, 9, 5),
  updatedAt: DateTime.utc(2026, 9, 5),
  messages: [
    ChatMessage(
      id: 'm-$id',
      role: MessageRole.assistant,
      createdAt: DateTime.utc(2026, 9, 5),
      blocks: const [TextBlock('hello')],
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('threads survive a reload', () async {
    final store = ChatThreadStore();
    await store.save('user-a', [_thread('t1'), _thread('t2')]);

    final restored = await ChatThreadStore().load('user-a');

    expect(restored.map((t) => t.id), ['t1', 't2']);
    expect(
      (restored.first.messages.single.blocks.single as TextBlock).text,
      'hello',
    );
  });

  test('another account does not see the previous account threads', () async {
    final store = ChatThreadStore();
    await store.save('user-a', [_thread('t1')]);

    expect(await store.load('user-b'), isEmpty);
  });

  test('corrupt stored json loads as empty rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      'chat_threads_v1': 'not json at all',
    });

    expect(await ChatThreadStore().load('user-a'), isEmpty);
  });

  test('a stored envelope stamped for another account returns empty', () async {
    SharedPreferences.setMockInitialValues({
      'chat_threads_v1': '{"user_id":"user-b","threads":[]}',
    });

    expect(await ChatThreadStore().load('user-a'), isEmpty);
  });

  test(
    'an envelope missing user_id returns empty rather than the threads',
    () async {
      SharedPreferences.setMockInitialValues({
        'chat_threads_v1':
            '{"threads":[{"id":"t1","title":"T","created_at":"2026-09-05T00:00:00.000Z","updated_at":"2026-09-05T00:00:00.000Z","messages":[]}]}',
      });

      expect(await ChatThreadStore().load('user-a'), isEmpty);
    },
  );

  test('valid json that is not an envelope object loads as empty', () async {
    SharedPreferences.setMockInitialValues({'chat_threads_v1': '[1,2,3]'});
    expect(await ChatThreadStore().load('user-a'), isEmpty);

    SharedPreferences.setMockInitialValues({'chat_threads_v1': '"hello"'});
    expect(await ChatThreadStore().load('user-a'), isEmpty);
  });

  test('round trip preserves nested answer blocks and timestamps', () async {
    final thread = _thread('t1');
    final store = ChatThreadStore();
    await store.save('user-a', [thread]);

    final restored = (await ChatThreadStore().load('user-a')).single;

    expect(restored.id, thread.id);
    expect(restored.title, thread.title);
    expect(restored.createdAt, thread.createdAt);
    expect(restored.updatedAt, thread.updatedAt);
    final restoredBlock = restored.messages.single.blocks.single;
    expect(restoredBlock, isA<TextBlock>());
    expect((restoredBlock as TextBlock).text, 'hello');
    expect(
      restored.messages.single.createdAt,
      thread.messages.single.createdAt,
    );
  });
}
