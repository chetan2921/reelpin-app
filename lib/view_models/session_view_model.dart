import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/http/account_http.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/utils/auth_error_message.dart';
import 'package:reelpin/http/sharing_http.dart';
import 'package:reelpin/services/sharing/share_handoff_service.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(
    this._authService,
    this._accountHttpFactory,
    this._sharingHttpFactory, {
    Future<void> Function()? unregisterPushToken,
  }) : _unregisterPushToken = unregisterPushToken {
    _session = _authService.currentSession;
    _subscription = _authService.authStateChanges.listen((state) {
      _session = state.session;
      if (state.session != null) {
        _forceSignedOut = false;
      }
      _error = null;
      notifyListeners();
      _syncProfileSilently();
      unawaited(_syncShareHandoffState());
    }, onError: AuthService.handleAuthStreamError);
    _bootstrap();
  }

  final AuthService _authService;
  final AccountHttp Function() _accountHttpFactory;
  final SharingHttp Function() _sharingHttpFactory;
  final Future<void> Function()? _unregisterPushToken;
  StreamSubscription<AuthState>? _subscription;

  Session? _session;
  bool _forceSignedOut = false;
  bool _isSigningIn = false;
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
  String? _error;
  String? _statusMessage;

  Session? get session => _session;
  User? get currentUser =>
      _forceSignedOut ? null : _session?.user ?? _authService.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get isSigningIn => _isSigningIn;
  bool get isSigningOut => _isSigningOut;
  bool get isDeletingAccount => _isDeletingAccount;
  bool get isBusy => _isSigningIn || _isSigningOut || _isDeletingAccount;
  String? get error => _error;
  String? get statusMessage => _statusMessage;

  String get email => currentUser?.email ?? '';

  String get displayName {
    final user = currentUser;
    if (user == null) return 'ReelPin User';

    final metadata = user.userMetadata;
    final fromMetadata = _readString(metadata, const [
      'full_name',
      'name',
      'user_name',
    ]);
    if (fromMetadata != null) return fromMetadata;

    final userEmail = user.email;
    if (userEmail != null && userEmail.contains('@')) {
      return userEmail.split('@').first;
    }

    return 'ReelPin User';
  }

  String? get avatarUrl =>
      _readString(currentUser?.userMetadata, const ['avatar_url', 'picture']);

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'RP';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<void> signInWithGoogle() async {
    if (_isSigningIn) return;

    _isSigningIn = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
      _forceSignedOut = false;
      unawaited(
        AnalyticsService.log(
          AnalyticsEvent.loginCompleted,
          parameters: {'method': 'google'},
        ),
      );
    } catch (e) {
      _error = authErrorMessage(e, operation: AuthOperation.signIn);
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signInWithApple() async {
    if (_isSigningIn) return;

    _isSigningIn = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithApple();
      _forceSignedOut = false;
      unawaited(
        AnalyticsService.log(
          AnalyticsEvent.loginCompleted,
          parameters: {'method': 'apple'},
        ),
      );
      await _syncProfileSilently();
    } catch (e) {
      _error = authErrorMessage(e, operation: AuthOperation.signIn);
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_isSigningOut) return;

    _isSigningOut = true;
    _error = null;
    notifyListeners();

    try {
      try {
        await _unregisterPushToken?.call();
      } catch (e) {
        AppLogger.error('Push token unregister skipped: $e');
      }
      // Revoke the device share token while the session is still valid so it
      // can't be used after sign-out.
      try {
        await _sharingHttpFactory().revokeShareToken();
      } catch (_) {}
      await _authService.signOut();
      _session = null;
      _forceSignedOut = true;
      unawaited(AnalyticsService.log(AnalyticsEvent.logoutCompleted));
      await ShareHandoffService.instance.clear();
      // Don't leave saved content on disk for whoever signs in next.
      await ContentCache.instance.clear();
    } catch (e) {
      _error = _normalizeError(e);
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    if (_isDeletingAccount) return false;

    _isDeletingAccount = true;
    _error = null;
    notifyListeners();

    try {
      await _accountHttpFactory().deleteAccount();
      try {
        await _unregisterPushToken?.call();
      } catch (e) {
        AppLogger.error('Push token unregister after deletion skipped: $e');
      }
      _session = null;
      _forceSignedOut = true;
      await ShareHandoffService.instance.clear();
      await ContentCache.instance.clear();
      try {
        await _authService.signOut();
      } catch (e) {
        AppLogger.error('Sign-out after account deletion skipped: $e');
      }
      return true;
    } catch (e) {
      _error = _normalizeError(e);
      return false;
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_isSigningIn) return false;

    _isSigningIn = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(email: email, password: password);
      _forceSignedOut = false;
      unawaited(
        AnalyticsService.log(
          AnalyticsEvent.loginCompleted,
          parameters: {'method': 'email'},
        ),
      );
      await _syncProfileSilently();
      return true;
    } catch (e) {
      _error = authErrorMessage(e, operation: AuthOperation.signIn);
      return false;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (_isSigningIn) return false;

    _isSigningIn = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.session == null) {
        _statusMessage =
            'ACCOUNT CREATED. CHECK YOUR EMAIL, VERIFY IT, THEN SIGN IN.';
      } else {
        _forceSignedOut = false;
        await _syncProfileSilently();
        _statusMessage = 'ACCOUNT READY. WELCOME TO REELPIN.';
      }
      unawaited(
        AnalyticsService.log(
          AnalyticsEvent.signupCompleted,
          parameters: {'method': 'email'},
        ),
      );
      return true;
    } catch (e) {
      _error = authErrorMessage(e, operation: AuthOperation.signUp);
      return false;
    } finally {
      _isSigningIn = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void clearStatusMessage() {
    if (_statusMessage == null) return;
    _statusMessage = null;
    notifyListeners();
  }

  /// Post-restore housekeeping, deliberately awaited by nothing on screen.
  ///
  /// The session is restored synchronously in the constructor, so the app
  /// already knows whether it has a user by the time the first frame builds.
  /// Neither call below feeds a screen — one upserts the profile row, the other
  /// mints the token the native share path uses — so gating the UI on them only
  /// held the splash up for the length of two network round trips.
  Future<void> _bootstrap() async {
    await _syncProfileSilently();
    await _syncShareHandoffState();
  }

  Future<void> _syncProfileSilently() async {
    if (currentUser == null) return;

    try {
      await _authService.ensureProfile();
    } catch (e) {
      AppLogger.error('Profile sync skipped: $e');
    }
  }

  Future<void> _syncShareHandoffState() async {
    final userId = currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      await ShareHandoffService.instance.clear();
      return;
    }

    await ShareHandoffService.instance.syncAuthenticatedUser(
      userId,
      _session?.accessToken ?? _authService.currentSession?.accessToken,
    );
    // Ensure a long-lived device share token exists so the native background
    // share path can enqueue without the user's short-lived session.
    await _ensureShareToken();
  }

  Future<void> _ensureShareToken() async {
    try {
      final existing = await ShareHandoffService.instance.getShareToken();
      if (existing != null && existing.isNotEmpty) return;
      final token = await _sharingHttpFactory().mintShareToken();
      if (token.isNotEmpty) {
        await ShareHandoffService.instance.setShareToken(token);
      }
    } catch (e) {
      AppLogger.error('Share token mint skipped: $e');
    }
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

  String _normalizeError(Object error) {
    final message = error.toString().trim();
    if (_looksTechnicalError(message)) {
      return userFacingErrorMessage(error);
    }
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  bool _looksTechnicalError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('exception') ||
        normalized.contains('socket') ||
        normalized.contains('connection closed') ||
        normalized.contains('connection refused') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('http://') ||
        normalized.contains('https://') ||
        normalized.contains('uri=');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
