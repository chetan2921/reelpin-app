import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Ceiling on undelimited buffered content between two `\n\n` boundaries.
/// A real answer is at most a few KB of JSON; this is generous headroom
/// against a stream that never sends a blank line, so a runaway response
/// fails fast instead of growing the buffer without limit.
const int _maxBufferChars = 256 * 1024;

/// Reads a `text/event-stream` body as chat events: progress stages, then
/// exactly one answer.
///
/// Shared by the private chat and a collection's shared thread, which speak
/// the identical protocol by design.
/// The caller owns the client and is responsible for closing it once this
/// stream ends, errors or is cancelled.
Stream<ChatEvent> readChatSse(
  http.StreamedResponse response, {
  required Duration timeout,
}) async* {
  var buffer = '';
  var sawAnswer = false;
  final lines = response.stream.transform(utf8.decoder).timeout(timeout);
  try {
    await for (final chunk in lines) {
      buffer += chunk;
      if (buffer.length > _maxBufferChars) {
        throw const ApiException(
          'Chat response was too large to process.',
          500,
        );
      }
      // A \r\n pair can straddle two chunks, so normalise on the
      // accumulated buffer rather than per chunk.
      buffer = buffer.replaceAll('\r\n', '\n');
      var boundary = buffer.indexOf('\n\n');
      while (boundary != -1) {
        final event = parseChatSseEvent(buffer.substring(0, boundary));
        buffer = buffer.substring(boundary + 2);
        if (event != null) {
          yield event;
          if (event is AnswerEvent) {
            sawAnswer = true;
            return;
          }
        }
        boundary = buffer.indexOf('\n\n');
      }
    }
  } on TimeoutException {
    throw const ApiException('Could not connect. Please try again.', 408);
  }

  // The body closed without a trailing blank line — today's backend
  // always sends one, but a proxy or crash could cut it off right after
  // the answer. Parse whatever's left rather than silently dropping it.
  if (buffer.trim().isNotEmpty) {
    final event = parseChatSseEvent(buffer);
    if (event != null) {
      yield event;
      if (event is AnswerEvent) sawAnswer = true;
    }
  }

  if (!sawAnswer) {
    // The body closed cleanly but never sent an answer or error — e.g.
    // a backend crash mid-thought. Without this, the view model's
    // await-for just completes and the message is stuck "sending"
    // forever with no way to retry.
    throw const ApiException(
      'The response ended unexpectedly. Please try again.',
      500,
      retryable: true,
    );
  }
}

/// One SSE event block (the lines between two blank lines). Returns null
/// for a block with no usable `data:` line — a keep-alive comment, or a
/// line that failed to parse as JSON — so one bad or empty event never
/// takes the rest of the stream down with it.
ChatEvent? parseChatSseEvent(String rawEvent) {
  final dataLines = <String>[];
  for (final line in rawEvent.split('\n')) {
    if (line.isEmpty || line.startsWith(':')) continue;
    if (line.startsWith('data:')) {
      dataLines.add(line.substring('data:'.length).trimLeft());
    }
  }
  if (dataLines.isEmpty) return null;

  final Map<String, dynamic> payload;
  try {
    payload = jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
  } catch (e) {
    if (kDebugMode) AppLogger.error('Chat SSE: malformed event ignored: $e');
    return null;
  }

  switch (payload['type']) {
    case 'stage':
      return StageEvent(
        ThinkingStage(
          label: payload['label']?.toString() ?? '',
          state: payload['state'] == 'done'
              ? ThinkingStageState.done
              : ThinkingStageState.active,
        ),
      );
    case 'answer':
      final blocksJson = payload['blocks'];
      final blocks = blocksJson is List
          ? blocksJson
                .whereType<Map>()
                .map((b) => AnswerBlock.fromJson(Map<String, dynamic>.from(b)))
                .whereType<AnswerBlock>()
                .toList()
          : <AnswerBlock>[];
      return AnswerEvent(blocks);
    case 'error':
      throw ApiException(
        payload['message']?.toString() ?? 'Something went wrong.',
        200,
        errorCode: payload['error_code']?.toString(),
        retryable: payload['retryable'] == true,
      );
    default:
      return null;
  }
}
