import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/chat_sse_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';

/// Real backend for a collection's shared AI thread.
///
/// Built like `ChatApiHttp`: a fresh client per call, closed when the call
/// ends, and a live question read through the same SSE parser the private
/// chat uses. Unlike the private chat's suggestions, every failure here
/// throws: this thread is the whole screen, and an empty page on error would
/// read as "nobody has asked anything yet".
class CollectionChatApiHttp implements CollectionChatHttp {
  CollectionChatApiHttp({
    http.Client Function()? clientFactory,
    String? baseUrl,
    String? Function()? accessTokenProvider,
    Duration? requestTimeout,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).trim(),
       _accessTokenProvider = accessTokenProvider ?? _currentAccessToken,
       _requestTimeout = requestTimeout ?? _defaultRequestTimeout;

  final http.Client Function() _clientFactory;
  final String _baseUrl;
  final String? Function() _accessTokenProvider;
  final Duration _requestTimeout;

  /// A live question waits on the model exactly as a private one does, so it
  /// gets the same ceiling — applied to opening the connection and to the gap
  /// between any two chunks of the stream.
  static const Duration _defaultRequestTimeout = Duration(seconds: 60);

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    String? after,
  }) async {
    final body = await _call(
      (client) => client.get(
        _uri(collectionId, query: {'after': ?after}),
        headers: _headers(),
      ),
    );
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? CollectionChatPage.fromJson(decoded)
        : const CollectionChatPage();
  }

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String text,
  }) async* {
    final client = _clientFactory();
    try {
      // No blocks: their absence is what makes this a live question rather
      // than a shared answer.
      final request = http.Request('POST', _uri(collectionId))
        ..headers.addAll(_headers(accept: 'text/event-stream'))
        ..body = jsonEncode({'text': text});

      final http.StreamedResponse response;
      try {
        response = await client.send(request).timeout(_requestTimeout);
      } on TimeoutException {
        throw const ApiException('Could not connect. Please try again.', 408);
      } on SocketException {
        throw const ApiException('Could not connect. Please try again.', 503);
      } on http.ClientException {
        throw const ApiException('Could not connect. Please try again.', 503);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionFrom(
          response.statusCode,
          await response.stream.bytesToString(),
        );
      }

      yield* readChatSse(response, timeout: _requestTimeout);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async {
    await _call(
      (client) => client.post(
        _uri(collectionId),
        headers: _headers(),
        body: jsonEncode({
          'text': questionText,
          'blocks': blocks.map((block) => block.toJson()).toList(),
          'source': 'shared',
        }),
      ),
    );
  }

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) async {
    await _call(
      (client) => client.delete(
        _uri(collectionId, messageId: messageId),
        headers: _headers(),
      ),
    );
  }

  /// One plain JSON call on its own client: the body on success, and an
  /// [ApiException] carrying the server's own message on anything else.
  Future<String> _call(
    Future<http.Response> Function(http.Client client) send,
  ) async {
    final client = _clientFactory();
    try {
      final response = await send(client).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionFrom(response.statusCode, response.body);
      }
      return response.body;
    } on TimeoutException {
      throw const ApiException('Could not connect. Please try again.', 408);
    } on SocketException {
      throw const ApiException('Could not connect. Please try again.', 503);
    } on http.ClientException {
      throw const ApiException('Could not connect. Please try again.', 503);
    } finally {
      client.close();
    }
  }

  Uri _uri(
    String collectionId, {
    String? messageId,
    Map<String, String> query = const {},
  }) {
    final base = _baseUrl.replaceFirst(RegExp(r'/$'), '');
    final thread =
        '$base/api/v1/collections/${Uri.encodeComponent(collectionId)}'
        '/chat/messages';
    final uri = Uri.parse(
      messageId == null ? thread : '$thread/${Uri.encodeComponent(messageId)}',
    );
    return query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({String accept = 'application/json'}) {
    final accessToken = _accessTokenProvider()?.trim();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': accept,
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  ApiException _exceptionFrom(int statusCode, String body) {
    const fallbackMessage =
        "This collection's chat is not available right now.";
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      return ApiException(
        payload['message']?.toString() ?? fallbackMessage,
        statusCode,
        errorCode: payload['error_code']?.toString(),
        detail: payload['detail']?.toString(),
        retryable: payload['retryable'] == true,
      );
    } catch (_) {
      return ApiException(fallbackMessage, statusCode);
    }
  }

  static String? _currentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
