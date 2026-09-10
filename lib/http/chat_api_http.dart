import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/chat_sse_http.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Real backend for chat: POSTs the question, then reads back a
/// `text/event-stream` of progress stages followed by exactly one answer
/// or error.
///
/// ApiClient's request methods all buffer a full [http.Response] before
/// returning, which would defeat the entire point of streaming stage
/// events as they arrive — so this talks to [http.Client.send] directly
/// instead of reusing ApiClient. A fresh client is opened per call (via
/// [_clientFactory]) and closed when the stream ends, errors or is
/// cancelled, rather than held as a field, since an SSE response keeps its
/// socket open for the life of the call.
class ChatApiHttp implements ChatHttp {
  ChatApiHttp({
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

  /// The backend calls Gemini to build an answer — 5-15s is a normal wait
  /// and this is the ceiling before giving up. Applied both to opening the
  /// connection and to the gap between any two chunks of the stream, so a
  /// server that stalls mid-answer is caught the same way as one that never
  /// responds at all. Overridable in tests so the mid-stream timeout path
  /// doesn't require an actual 60s wait.
  static const Duration _defaultRequestTimeout = Duration(seconds: 60);

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    List<ChatHistoryEntry> history = const [],
  }) async* {
    final client = _clientFactory();
    try {
      final request = http.Request('POST', _uri())
        ..headers.addAll(_headers())
        ..body = jsonEncode({
          'thread_id': threadId,
          'text': text,
          if (attachments.isNotEmpty)
            'attachments': attachments.map(_attachmentJson).toList(),
          if (history.isNotEmpty)
            'history': history.map((e) => e.toJson()).toList(),
        });

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
        throw await _exceptionFromResponse(response);
      }

      yield* readChatSse(response, timeout: _requestTimeout);
    } finally {
      client.close();
    }
  }

  @override
  Future<List<String>> fetchSuggestions() async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            _uri('chat/suggestions'),
            headers: _headers(accept: 'application/json'),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      final raw = payload is Map<String, dynamic>
          ? payload['suggestions']
          : null;
      if (raw is! List) return const [];
      return raw
          .map((s) => s.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      // Not on the critical path — the empty screen falls back to its own
      // generic suggestions, so a failure here should never surface as an
      // error to the user.
      if (kDebugMode) AppLogger.error('Chat suggestions: fetch failed: $e');
      return const [];
    } finally {
      client.close();
    }
  }

  Uri _uri([String path = 'chat/messages']) {
    final base = _baseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base/api/v1/$path');
  }

  Map<String, String> _headers({String accept = 'text/event-stream'}) {
    final accessToken = _accessTokenProvider()?.trim();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': accept,
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  /// Backend's `kind` values are snake_case (`chat.retrieve` matches the
  /// literal strings `"saved_reel"` and `"link"`), but our
  /// [AttachmentKind] enum is camelCase because [ChatAttachment.toJson]
  /// also serialises it for local thread storage. Map it here rather than
  /// there, so the wire format and the storage format can diverge safely.
  Map<String, dynamic> _attachmentJson(ChatAttachment attachment) => {
    'kind': switch (attachment.kind) {
      AttachmentKind.photo => 'photo',
      AttachmentKind.camera => 'camera',
      AttachmentKind.file => 'file',
      AttachmentKind.savedReel => 'saved_reel',
      AttachmentKind.link => 'link',
      AttachmentKind.collection => 'collection',
    },
    if (attachment.reelId != null) 'reel_id': attachment.reelId,
    if (attachment.url != null) 'url': attachment.url,
    if (attachment.collectionId != null)
      'collection_id': attachment.collectionId,
  };

  Future<ApiException> _exceptionFromResponse(
    http.StreamedResponse response,
  ) async {
    final fallbackMessage = 'Chat is not available right now.';
    try {
      final body = await response.stream.bytesToString();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      return ApiException(
        payload['message']?.toString() ?? fallbackMessage,
        response.statusCode,
        errorCode: payload['error_code']?.toString(),
        detail: payload['detail']?.toString(),
        retryable: payload['retryable'] == true,
      );
    } catch (_) {
      return ApiException(fallbackMessage, response.statusCode);
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
