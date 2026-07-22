import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthOperation { signIn, signUp }

String authErrorMessage(Object error, {required AuthOperation operation}) {
  if (_isConnectionError(error)) {
    return 'Check your connection and try again.';
  }

  if (error is AuthUnknownException &&
      _isConnectionError(error.originalError)) {
    return 'Check your connection and try again.';
  }

  if (error is AuthException) {
    final code = error.code?.trim().toLowerCase();
    switch (code) {
      case 'invalid_credentials':
      case 'user_not_found':
        return 'Incorrect email or password. New here? Sign up.';
      case 'email_not_confirmed':
        return 'Verify your email before signing in.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Account already exists. Sign in instead.';
      case 'weak_password':
        return 'Choose a stronger password.';
      case 'over_request_rate_limit':
        return 'Too many attempts. Try again later.';
      case 'over_email_send_rate_limit':
        return 'Too many emails sent. Try again later.';
      case 'signup_disabled':
        return 'Sign up is currently unavailable.';
      case 'email_provider_disabled':
        return 'Email sign-in is currently unavailable.';
      case 'provider_disabled':
      case 'oauth_provider_not_supported':
        return 'This sign-in method is unavailable.';
      case 'user_banned':
        return 'This account is unavailable.';
      case 'captcha_failed':
        return 'Verification failed. Try again.';
      case 'request_timeout':
        return 'Request timed out. Try again.';
    }

    if (error.statusCode == '429') {
      return 'Too many attempts. Try again later.';
    }

    final legacyMessage = error.message.trim().toLowerCase();
    if (legacyMessage.contains('invalid login credentials')) {
      return 'Incorrect email or password. New here? Sign up.';
    }
    if (legacyMessage.contains('email not confirmed')) {
      return 'Verify your email before signing in.';
    }
    if (legacyMessage.contains('user already registered')) {
      return 'Account already exists. Sign in instead.';
    }
    if (legacyMessage.contains('password should be')) {
      return 'Choose a stronger password.';
    }
  }

  final message = error.toString().replaceFirst('Exception: ', '').trim();
  switch (message) {
    case 'Apple sign-in was cancelled.':
    case 'Sign in with Apple is not available on this device.':
      return message;
    case 'Apple sign-in did not return an identity token.':
    case 'Apple sign-in could not be completed.':
      return 'Could not sign in with Apple. Try again.';
  }

  return operation == AuthOperation.signUp
      ? 'Could not create account. Try again.'
      : 'Could not sign in. Try again.';
}

bool _isConnectionError(Object error) {
  return error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException;
}
