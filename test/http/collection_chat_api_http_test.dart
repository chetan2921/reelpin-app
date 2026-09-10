import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_api_http.dart';

const _collectionId = '55555555-5555-5555-5555-555555555555';
const _threadUrl =
    'https://example.com/api/v1/collections/$_collectionId/chat/messages';

/// Every request goes to [handler]; [onRequest] sees the request and its body
/// first, so a test can assert what was actually put on the wire.
CollectionChatApiHttp _client(
  Future<http.StreamedResponse> Function(http.BaseRequest request) handler, {
  void Function(http.BaseRequest request, String body)? onRequest,
}) {
  final mock = MockClient.streaming((request, bodyStream) async {
    final body = await bodyStream.bytesToString();
    onRequest?.call(request, body);
    return handler(request);
  });
  return CollectionChatApiHttp(
    clientFactory: () => mock,
    baseUrl: 'https://example.com',
    accessTokenProvider: () => 'token-123',
  );
}

http.StreamedResponse _json(Object body, [int status = 200]) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status);

http.StreamedResponse _sse(List<String> chunks) =>
    http.StreamedResponse(Stream.fromIterable(chunks.map(utf8.encode)), 200);

void main() {
  test(
    'fetchMessages reads the thread, with the token on the request',
    () async {
      late http.BaseRequest seen;
      final api = _client(
        (_) async => _json({
          'messages': [
            {
              'id': 'm1',
              'role': 'user',
              'author_name': 'Priya',
              'text': 'Where do we start?',
              'created_at': '2026-09-11T10:00:00+00:00',
            },
            {
              'id': 'm2',
              'role': 'assistant',
              'source': 'shared',
              'blocks': [
                {'type': 'text', 'text': 'The ramen bar.'},
              ],
              'created_at': '2026-09-11T10:00:05+00:00',
            },
          ],
        }),
        onRequest: (request, _) => seen = request,
      );

      final page = await api.fetchMessages(_collectionId);

      expect(seen.method, 'GET');
      // No `after` on a first read: the whole thread, from the start.
      expect(seen.url.toString(), _threadUrl);
      expect(seen.headers['Authorization'], 'Bearer token-123');
      expect(page.messages.first.authorName, 'Priya');
      expect(page.messages.first.text, 'Where do we start?');
      expect(page.messages.last.isShared, isTrue);
      expect(
        (page.messages.last.blocks.single as TextBlock).text,
        'The ramen bar.',
      );
    },
  );

  test('after rides along as a query parameter', () async {
    late http.BaseRequest seen;
    final api = _client(
      (_) async => _json({'messages': []}),
      onRequest: (request, _) => seen = request,
    );

    await api.fetchMessages(_collectionId, after: 'm7');

    expect(seen.url.queryParameters['after'], 'm7');
  });

  test(
    'a failed read throws the server message instead of an empty thread',
    () async {
      final api = _client(
        (_) async => _json({
          'message': 'That collection was not found.',
          'error_code': 'collection_not_found',
        }, 404),
      );

      // An empty page here would read as "nobody has asked anything yet",
      // which is a lie the screen cannot tell apart from the truth.
      expect(
        () => api.fetchMessages(_collectionId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having(
                (e) => e.message,
                'message',
                'That collection was not found.',
              ),
        ),
      );
    },
  );

  test('an unreachable server surfaces as a connection error', () async {
    final api = _client((_) async => throw http.ClientException('offline'));

    expect(
      () => api.fetchMessages(_collectionId),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503),
      ),
    );
  });

  test('ask posts the question, then streams stages and one answer', () async {
    late http.BaseRequest seen;
    late String body;
    final api = _client(
      (_) async => _sse([
        'data: {"type":"stage","label":"READING THIS COLLECTION","state":"active"}\n\n',
        'data: {"type":"answer","blocks":[{"type":"text","text":"The ramen bar."}]}\n\n',
      ]),
      onRequest: (request, requestBody) {
        seen = request;
        body = requestBody;
      },
    );

    final events = await api
        .ask(collectionId: _collectionId, text: 'Where do we start?')
        .toList();

    expect(seen.method, 'POST');
    expect(seen.url.toString(), _threadUrl);
    expect(seen.headers['Accept'], 'text/event-stream');
    // No blocks: that absence is what makes this a live question.
    expect(jsonDecode(body), {'text': 'Where do we start?'});
    expect(events.first, isA<StageEvent>());
    expect(events.last, isA<AnswerEvent>());
  });

  test("a viewer's ask fails with the server's 403", () async {
    final api = _client(
      (_) async => _json({
        'message': 'You do not have permission to change this collection.',
        'error_code': 'collection_forbidden',
      }, 403),
    );

    expect(
      api.ask(collectionId: _collectionId, text: 'hello').toList(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.errorCode, 'errorCode', 'collection_forbidden'),
      ),
    );
  });

  test(
    'shareAnswer posts the blocks as a shared answer, as plain JSON',
    () async {
      late http.BaseRequest seen;
      late String body;
      final api = _client(
        (_) async => _json({'messages': []}),
        onRequest: (request, requestBody) {
          seen = request;
          body = requestBody;
        },
      );

      await api.shareAnswer(
        collectionId: _collectionId,
        questionText: 'Asked privately',
        blocks: const [
          TextBlock('The ramen bar.'),
          ReelRefsBlock(['r1']),
        ],
      );

      expect(seen.method, 'POST');
      expect(seen.url.toString(), _threadUrl);
      expect(seen.headers['Accept'], 'application/json');
      expect(jsonDecode(body), {
        'text': 'Asked privately',
        'blocks': [
          {'type': 'text', 'text': 'The ramen bar.'},
          {
            'type': 'reel_refs',
            'reel_ids': ['r1'],
          },
        ],
        'source': 'shared',
      });
    },
  );

  test('a refused share throws, so the snackbar can say why', () async {
    final api = _client(
      (_) async => _json({
        'message': 'There is nothing in that answer to add.',
        'error_code': 'invalid_request',
      }, 400),
    );

    expect(
      () => api.shareAnswer(
        collectionId: _collectionId,
        questionText: '',
        blocks: const [],
      ),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('deleteMessage sends a DELETE for that one message', () async {
    late http.BaseRequest seen;
    final api = _client(
      (_) async => _json({'ok': true}),
      onRequest: (request, _) => seen = request,
    );

    await api.deleteMessage(collectionId: _collectionId, messageId: 'm1');

    expect(seen.method, 'DELETE');
    expect(seen.url.toString(), '$_threadUrl/m1');
  });
}
