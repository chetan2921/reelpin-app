import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:reelpin/http/api_exception.dart';

String userFacingErrorMessage(
  Object error, {
  String fallbackMessage = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) {
    final message = error.message.trim();
    if (message.isEmpty) {
      return fallbackMessage;
    }
    return _looksTechnicalError(message)
        ? _technicalErrorFallback(error, fallbackMessage)
        : message;
  }

  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return 'Could not connect. Please try again.';
  }

  return fallbackMessage;
}

bool _looksTechnicalError(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('exception') ||
      normalized.contains('socket') ||
      normalized.contains('connection closed') ||
      normalized.contains('connection refused') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('request failed') ||
      normalized.contains('status code') ||
      normalized.contains('internal server error') ||
      normalized.contains('http://') ||
      normalized.contains('https://') ||
      normalized.contains('uri=');
}

String _technicalErrorFallback(ApiException error, String fallbackMessage) {
  if (error.statusCode == 408 || error.statusCode == 503) {
    return 'Could not connect. Please try again.';
  }
  return fallbackMessage;
}
