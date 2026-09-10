import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';

void main() {
  test('a thread round-trips through json with every block type', () {
    final thread = ChatThread(
      id: 't1',
      title: 'Tokyo food',
      createdAt: DateTime.utc(2026, 9, 5, 10),
      updatedAt: DateTime.utc(2026, 9, 5, 11),
      messages: [
        ChatMessage(
          id: 'm1',
          role: MessageRole.user,
          text: 'what did I save about ramen?',
          createdAt: DateTime.utc(2026, 9, 5, 10),
          attachments: const [
            ChatAttachment(
              kind: AttachmentKind.link,
              displayName: 'instagram.com/p/abc',
              url: 'https://instagram.com/p/abc',
            ),
          ],
        ),
        ChatMessage(
          id: 'm2',
          role: MessageRole.assistant,
          createdAt: DateTime.utc(2026, 9, 5, 11),
          blocks: const [
            TextBlock('You saved three ramen places.'),
            ReelRefsBlock(['r1', 'r2', 'r3']),
            PlacesBlock([
              AnswerPlace(
                name: 'Ichiran',
                latitude: 35.66,
                longitude: 139.7,
                category: 'Food',
                reelId: 'r1',
              ),
            ]),
            TableBlock(
              columns: ['Shop', 'Broth'],
              rows: [
                ['Ichiran', 'Tonkotsu'],
              ],
            ),
            ChartBlock(
              title: 'Saves by category',
              bars: [ChartBar(label: 'FOOD', value: 12, category: 'Food')],
            ),
          ],
        ),
      ],
    );

    // Cross a real JSON string boundary rather than handing the in-memory
    // Map straight back, so this actually exercises encoding, not just the
    // fromJson/toJson shapes agreeing with each other in memory.
    final restored = ChatThread.fromJson(
      jsonDecode(jsonEncode(thread.toJson())) as Map<String, dynamic>,
    );

    expect(restored.id, 't1');
    expect(restored.title, 'Tokyo food');
    expect(restored.updatedAt, DateTime.utc(2026, 9, 5, 11));
    expect(restored.messages, hasLength(2));

    final userMessage = restored.messages.first;
    expect(userMessage.text, 'what did I save about ramen?');
    expect(userMessage.attachments.single.kind, AttachmentKind.link);
    expect(userMessage.attachments.single.displayName, 'instagram.com/p/abc');
    expect(userMessage.attachments.single.url, 'https://instagram.com/p/abc');

    final blocks = restored.messages.last.blocks;
    expect(blocks.map((b) => b.runtimeType).toList(), [
      TextBlock,
      ReelRefsBlock,
      PlacesBlock,
      TableBlock,
      ChartBlock,
    ]);

    expect((blocks[0] as TextBlock).text, 'You saved three ramen places.');
    expect((blocks[1] as ReelRefsBlock).reelIds, ['r1', 'r2', 'r3']);

    final places = (blocks[2] as PlacesBlock).places;
    expect(places.single.name, 'Ichiran');
    expect(places.single.latitude, 35.66);
    expect(places.single.longitude, 139.7);
    expect(places.single.category, 'Food');
    expect(places.single.reelId, 'r1');

    final table = blocks[3] as TableBlock;
    expect(table.columns, ['Shop', 'Broth']);
    expect(table.rows, [
      ['Ichiran', 'Tonkotsu'],
    ]);

    final chart = blocks[4] as ChartBlock;
    expect(chart.title, 'Saves by category');
    expect(chart.bars.single.label, 'FOOD');
    expect(chart.bars.single.value, 12);
    expect(chart.bars.single.category, 'Food');
  });

  test('an unknown block type is dropped rather than crashing the thread', () {
    final json = {
      'id': 't2',
      'title': 'Old thread',
      'created_at': '2026-09-05T10:00:00.000Z',
      'updated_at': '2026-09-05T10:00:00.000Z',
      'messages': [
        {
          'id': 'm1',
          'role': 'assistant',
          'created_at': '2026-09-05T10:00:00.000Z',
          'status': 'complete',
          'blocks': [
            {'type': 'text', 'text': 'kept'},
            {'type': 'from_the_future', 'payload': 42},
          ],
        },
      ],
    };

    final thread = ChatThread.fromJson(json);

    expect(thread.messages.single.blocks, hasLength(1));
    expect((thread.messages.single.blocks.single as TextBlock).text, 'kept');
  });

  test(
    'wrong-typed fields inside a message degrade to empty defaults instead of throwing',
    () {
      final json = {
        'id': 't3',
        'title': 'Malformed thread',
        'created_at': '2026-09-05T10:00:00.000Z',
        'updated_at': '2026-09-05T10:00:00.000Z',
        'messages': [
          {
            'id': 'm1',
            'role': 'assistant',
            'created_at': '2026-09-05T10:00:00.000Z',
            'status': 'complete',
            // A String where a List was expected.
            'attachments': 7,
            'blocks': [
              // A String where a List was expected.
              {'type': 'reel_refs', 'reel_ids': 'oops'},
              {
                'type': 'places',
                'places': [
                  {
                    'name': 'Ichiran',
                    // A numeric string still parses...
                    'latitude': '35.66',
                    // ...but a non-numeric one falls back to 0.
                    'longitude': 'nope',
                  },
                ],
              },
              // Maps where a List was expected.
              {'type': 'table', 'columns': {}, 'rows': {}},
              // A number where a List was expected.
              {'type': 'chart', 'title': 'x', 'bars': 3},
            ],
          },
        ],
      };

      late ChatThread thread;
      expect(() => thread = ChatThread.fromJson(json), returnsNormally);

      final message = thread.messages.single;
      expect(message.attachments, isEmpty);

      final refs = message.blocks[0] as ReelRefsBlock;
      expect(refs.reelIds, isEmpty);

      final places = (message.blocks[1] as PlacesBlock).places;
      expect(places.single.latitude, 35.66);
      expect(places.single.longitude, 0);

      final table = message.blocks[2] as TableBlock;
      expect(table.columns, isEmpty);
      expect(table.rows, isEmpty);

      final chart = message.blocks[3] as ChartBlock;
      expect(chart.bars, isEmpty);
    },
  );

  test(
    'a thread whose top-level messages field is wrong-typed still parses',
    () {
      final json = {
        'id': 't4',
        'title': 'Bad messages',
        'created_at': '2026-09-05T10:00:00.000Z',
        'updated_at': '2026-09-05T10:00:00.000Z',
        // A String where a List was expected.
        'messages': 'junk',
      };

      late ChatThread thread;
      expect(() => thread = ChatThread.fromJson(json), returnsNormally);
      expect(thread.messages, isEmpty);
    },
  );
}
