import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_api_http.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/api_exception.dart';

/// Builds a streamed 200 response whose body arrives as exactly the given
/// chunks — each string in [chunks] is delivered to the client as one
/// separate stream event, so tests can control chunk boundaries precisely.
http.StreamedResponse _sseResponse(List<String> chunks) {
  return http.StreamedResponse(
    Stream.fromIterable(chunks.map(utf8.encode)),
    200,
  );
}

ChatApiHttp _client(
  Future<http.StreamedResponse> Function(http.BaseRequest, http.ByteStream)
  handler, {
  void Function(String body)? onBody,
}) {
  final mock = MockClient.streaming((request, bodyStream) async {
    if (onBody != null) onBody(await bodyStream.bytesToString());
    return handler(request, bodyStream);
  });
  return ChatApiHttp(
    clientFactory: () => mock,
    baseUrl: 'https://example.com',
    accessTokenProvider: () => 'token-123',
  );
}

void main() {
  test('stages arrive in order, then the answer last', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {"type":"stage","label":"SEARCHING","state":"active"}\n\n'
            'data: {"type":"stage","label":"SEARCHING","state":"done"}\n\n'
            'data: {"type":"answer","blocks":[{"type":"text","text":"hi"}]}\n\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(3));
    expect(events[0], isA<StageEvent>());
    expect((events[0] as StageEvent).stage.state, ThinkingStageState.active);
    expect(events[1], isA<StageEvent>());
    expect((events[1] as StageEvent).stage.state, ThinkingStageState.done);
    expect(events[2], isA<AnswerEvent>());
    expect(
      (events[2] as AnswerEvent).blocks.single,
      isA<TextBlock>().having((b) => b.text, 'text', 'hi'),
    );
  });

  test('an event split across two chunks is parsed correctly', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {"type":"stage","label":"SEA',
        'RCHING","state":"active"}\n\n'
            'data: {"type":"answer","blocks":[]}\n\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(2));
    expect((events[0] as StageEvent).stage.label, 'SEARCHING');
    expect(events[1], isA<AnswerEvent>());
  });

  test('two events arriving in one chunk are both parsed', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {"type":"stage","label":"A","state":"active"}\n\n'
            'data: {"type":"stage","label":"B","state":"active"}\n\n'
            'data: {"type":"answer","blocks":[]}\n\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(3));
    expect((events[0] as StageEvent).stage.label, 'A');
    expect((events[1] as StageEvent).stage.label, 'B');
    expect(events[2], isA<AnswerEvent>());
  });

  test('blank lines and keep-alive comments are ignored', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        '\n\n'
            ': keep-alive\n\n'
            'data: {"type":"stage","label":"A","state":"active"}\n\n'
            '\n\n'
            'data: {"type":"answer","blocks":[]}\n\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(2));
    expect((events[0] as StageEvent).stage.label, 'A');
    expect(events[1], isA<AnswerEvent>());
  });

  test('a type:error event surfaces as an ApiException', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {"type":"error","message":"Could not reach the model.",'
            '"error_code":"upstream_unavailable","retryable":true}\n\n',
      ]);
    });

    await expectLater(
      chatHttp.sendMessage(threadId: 't1', text: 'hello').toList(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Could not reach the model.')
            .having((e) => e.errorCode, 'errorCode', 'upstream_unavailable')
            .having((e) => e.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('a malformed data line does not kill the stream', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {not valid json\n\n'
            'data: {"type":"stage","label":"A","state":"active"}\n\n'
            'data: {"type":"answer","blocks":[]}\n\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(2));
    expect((events[0] as StageEvent).stage.label, 'A');
    expect(events[1], isA<AnswerEvent>());
  });

  test('a 401 before the stream opens becomes an ApiException', () async {
    final chatHttp = _client((_, _) async {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'success': false,
              'error_code': 'authentication_required',
              'message': 'Sign in is required.',
              'retryable': false,
            }),
          ),
        ),
        401,
      );
    });

    await expectLater(
      chatHttp.sendMessage(threadId: 't1', text: 'hello').toList(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Sign in is required.')
            .having((e) => e.errorCode, 'errorCode', 'authentication_required'),
      ),
    );
  });

  test('a CRLF-delimited stream yields its events', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {"type":"stage","label":"SEARCHING","state":"active"}\r\n\r\n'
            'data: {"type":"answer","blocks":[{"type":"text","text":"hi"}]}\r\n\r\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(2));
    expect((events[0] as StageEvent).stage.label, 'SEARCHING');
    expect(
      (events[1] as AnswerEvent).blocks.single,
      isA<TextBlock>().having((b) => b.text, 'text', 'hi'),
    );
  });

  test('a \\r\\n pair split across two chunks still parses', () async {
    final chatHttp = _client((_, _) async {
      return _sseResponse([
        'data: {"type":"stage","label":"A","state":"active"}\r',
        '\n\r\ndata: {"type":"answer","blocks":[]}\r\n\r\n',
      ]);
    });

    final events = await chatHttp
        .sendMessage(threadId: 't1', text: 'hello')
        .toList();

    expect(events, hasLength(2));
    expect((events[0] as StageEvent).stage.label, 'A');
    expect(events[1], isA<AnswerEvent>());
  });

  test(
    'a stream ending without a trailing blank line still emits its final answer',
    () async {
      final chatHttp = _client((_, _) async {
        return _sseResponse([
          'data: {"type":"stage","label":"A","state":"active"}\n\n'
              'data: {"type":"answer","blocks":[{"type":"text","text":"hi"}]}\n',
        ]);
      });

      final events = await chatHttp
          .sendMessage(threadId: 't1', text: 'hello')
          .toList();

      expect(events, hasLength(2));
      expect(
        (events[1] as AnswerEvent).blocks.single,
        isA<TextBlock>().having((b) => b.text, 'text', 'hi'),
      );
    },
  );

  test(
    'a stream that ends after stages with no answer or error throws',
    () async {
      final chatHttp = _client((_, _) async {
        return _sseResponse([
          'data: {"type":"stage","label":"A","state":"active"}\n\n'
              'data: {"type":"stage","label":"A","state":"done"}\n\n',
        ]);
      });

      await expectLater(
        chatHttp.sendMessage(threadId: 't1', text: 'hello').toList(),
        throwsA(
          isA<ApiException>().having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    },
  );

  test('the buffer cap throws instead of growing unbounded', () async {
    final chatHttp = _client((_, _) async {
      // Never a "\n\n" boundary, so the buffer just keeps growing.
      return _sseResponse(['x' * (300 * 1024)]);
    });

    await expectLater(
      chatHttp.sendMessage(threadId: 't1', text: 'hello').toList(),
      throwsA(isA<ApiException>()),
    );
  });

  test('a mid-stream body timeout surfaces as an ApiException', () async {
    final mock = MockClient.streaming((_, _) async {
      return http.StreamedResponse(
        (() async* {
          yield utf8.encode(
            'data: {"type":"stage","label":"A","state":"active"}\n\n',
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        })(),
        200,
      );
    });
    final chatHttp = ChatApiHttp(
      clientFactory: () => mock,
      baseUrl: 'https://example.com',
      accessTokenProvider: () => 'token-123',
      requestTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      chatHttp.sendMessage(threadId: 't1', text: 'hello').toList(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 408),
      ),
    );
  });

  test('savedReel attachments are sent on the wire as saved_reel', () async {
    late String capturedBody;
    final chatHttp = _client(
      (_, _) async => _sseResponse(['data: {"type":"answer","blocks":[]}\n\n']),
      onBody: (body) => capturedBody = body,
    );

    await chatHttp
        .sendMessage(
          threadId: 't1',
          text: '',
          attachments: const [
            ChatAttachment(
              kind: AttachmentKind.savedReel,
              displayName: 'My reel',
              reelId: 'r1',
            ),
          ],
        )
        .toList();

    final decoded = jsonDecode(capturedBody) as Map<String, dynamic>;
    final attachments = decoded['attachments'] as List;
    expect(attachments.single, {'kind': 'saved_reel', 'reel_id': 'r1'});
  });

  test(
    'collection attachments are sent on the wire with collection_id',
    () async {
      late String capturedBody;
      final chatHttp = _client(
        (_, _) async =>
            _sseResponse(['data: {"type":"answer","blocks":[]}\n\n']),
        onBody: (body) => capturedBody = body,
      );

      await chatHttp
          .sendMessage(
            threadId: 't1',
            text: '',
            attachments: const [
              ChatAttachment(
                kind: AttachmentKind.collection,
                displayName: 'Tokyo trip',
                collectionId: 'c1',
              ),
            ],
          )
          .toList();

      final decoded = jsonDecode(capturedBody) as Map<String, dynamic>;
      final attachments = decoded['attachments'] as List;
      expect(attachments.single, {'kind': 'collection', 'collection_id': 'c1'});
    },
  );

  test('history is sent oldest first', () async {
    late String capturedBody;
    final chatHttp = _client(
      (_, _) async => _sseResponse(['data: {"type":"answer","blocks":[]}\n\n']),
      onBody: (body) => capturedBody = body,
    );

    await chatHttp
        .sendMessage(
          threadId: 't1',
          text: 'compare those two',
          history: const [
            ChatHistoryEntry(role: 'user', text: 'what ramen did I save?'),
            ChatHistoryEntry(role: 'assistant', text: 'You saved three.'),
          ],
        )
        .toList();

    final decoded = jsonDecode(capturedBody) as Map<String, dynamic>;
    expect(decoded['history'], [
      {'role': 'user', 'text': 'what ramen did I save?'},
      {'role': 'assistant', 'text': 'You saved three.'},
    ]);
  });

  test('an empty history is left off the wire entirely', () async {
    late String capturedBody;
    final chatHttp = _client(
      (_, _) async => _sseResponse(['data: {"type":"answer","blocks":[]}\n\n']),
      onBody: (body) => capturedBody = body,
    );

    await chatHttp.sendMessage(threadId: 't1', text: 'first question').toList();

    expect(
      (jsonDecode(capturedBody) as Map<String, dynamic>).containsKey('history'),
      isFalse,
    );
  });
}
