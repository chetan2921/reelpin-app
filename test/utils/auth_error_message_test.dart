import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/utils/auth_error_message.dart';

void main() {
  group('authErrorMessage', () {
    test('maps sign-in errors to short recovery messages', () {
      expect(
        authErrorMessage(
          AuthApiException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
          operation: AuthOperation.signIn,
        ),
        'Incorrect email or password. New here? Sign up.',
      );
      expect(
        authErrorMessage(
          AuthApiException(
            'Email not confirmed',
            statusCode: '400',
            code: 'email_not_confirmed',
          ),
          operation: AuthOperation.signIn,
        ),
        'Verify your email before signing in.',
      );
    });

    test('maps sign-up errors to short recovery messages', () {
      expect(
        authErrorMessage(
          AuthApiException(
            'User already registered',
            statusCode: '422',
            code: 'user_already_exists',
          ),
          operation: AuthOperation.signUp,
        ),
        'Account already exists. Sign in instead.',
      );
      expect(
        authErrorMessage(
          AuthApiException(
            'Password is too weak',
            statusCode: '422',
            code: 'weak_password',
          ),
          operation: AuthOperation.signUp,
        ),
        'Choose a stronger password.',
      );
    });

    test('maps rate limits and connection errors', () {
      expect(
        authErrorMessage(
          AuthApiException(
            'Too many requests',
            statusCode: '429',
            code: 'over_request_rate_limit',
          ),
          operation: AuthOperation.signIn,
        ),
        'Too many attempts. Try again later.',
      );
      expect(
        authErrorMessage(
          TimeoutException('Request timed out'),
          operation: AuthOperation.signIn,
        ),
        'Check your connection and try again.',
      );
    });

    test('uses operation-specific fallback messages', () {
      expect(
        authErrorMessage(
          Exception('Unexpected failure'),
          operation: AuthOperation.signIn,
        ),
        'Could not sign in. Try again.',
      );
      expect(
        authErrorMessage(
          Exception('Unexpected failure'),
          operation: AuthOperation.signUp,
        ),
        'Could not create account. Try again.',
      );
    });
  });
}
