import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/env.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/auth/supabase_client.dart';

class AuthService {
  AuthService(this._profileService);

  final ProfileService _profileService;

  Session? get currentSession => supabase.auth.currentSession;
  User? get currentUser => supabase.auth.currentUser;

  /// Every listener must pass [handleAuthStreamError] as `onError`: gotrue
  /// reports failed token refreshes as errors on this stream, and one with no
  /// handler is an uncaught error.
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Handles an error gotrue pushed down [authStateChanges].
  ///
  /// A background token refresh that fails on the network — a 504, a
  /// connection dropped when the app is backgrounded — arrives as
  /// [AuthRetryableFetchException]. gotrue keeps the session and retries on
  /// its next tick, so there is nothing to do. Anything else is reported.
  static void handleAuthStreamError(Object error, StackTrace stack) {
    if (error is AuthRetryableFetchException) return;
    unawaited(AnalyticsService.recordError(error, stack));
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) {
    return supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
      emailRedirectTo: SupabaseConfig.redirectUrl,
    );
  }

  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<AuthResponse> signInWithApple() async {
    final rawNonce = supabase.auth.generateRawNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.trim().isEmpty) {
        throw Exception('Apple sign-in did not return an identity token.');
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce,
      );

      final user = response.user ?? currentUser;
      if (user != null) {
        await _profileService.upsertProfile(
          id: user.id,
          email: user.email ?? credential.email,
          fullName: _appleFullName(credential),
        );
      }

      return response;
    } on SignInWithAppleNotSupportedException {
      throw Exception('Sign in with Apple is not available on this device.');
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple sign-in was cancelled.');
      }
      throw Exception('Apple sign-in could not be completed.');
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> ensureProfile() async {
    final user = currentUser;
    if (user == null) return;

    await _profileService.upsertProfile(
      id: user.id,
      email: user.email,
      fullName: _readString(user.userMetadata, const [
        'full_name',
        'name',
        'user_name',
      ]),
      avatarUrl: _readString(user.userMetadata, const [
        'avatar_url',
        'picture',
      ]),
    );
  }

  String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;

    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  String? _appleFullName(AuthorizationCredentialAppleID credential) {
    final parts = [
      credential.givenName?.trim(),
      credential.familyName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String _sha256(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
