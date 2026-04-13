import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/share_handoff_service.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._authService) {
    _session = _authService.currentSession;
    _subscription = _authService.authStateChanges.listen((state) {
      _session = state.session;
      _error = null;
      notifyListeners();
      _syncProfileSilently();
      unawaited(_syncShareHandoffState());
    });
    _bootstrap();
  }

  final AuthService _authService;
  StreamSubscription<AuthState>? _subscription;

  Session? _session;
  bool _isBootstrapping = true;
  bool _isSigningIn = false;
  bool _isSigningOut = false;
  String? _error;
  String? _statusMessage;

  Session? get session => _session;
  User? get currentUser => _session?.user ?? _authService.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get isBootstrapping => _isBootstrapping;
  bool get isSigningIn => _isSigningIn;
  bool get isSigningOut => _isSigningOut;
  bool get isBusy => _isSigningIn || _isSigningOut;
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
    } catch (e) {
      _error = _normalizeError(e);
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
      await _authService.signOut();
      _session = null;
      await ShareHandoffService.instance.clear();
    } catch (e) {
      _error = _normalizeError(e);
    } finally {
      _isSigningOut = false;
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
      await _syncProfileSilently();
      return true;
    } catch (e) {
      _error = _normalizeError(e);
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
        await _syncProfileSilently();
        _statusMessage = 'ACCOUNT READY. WELCOME TO REELPIN.';
      }
      return true;
    } catch (e) {
      _error = _normalizeError(e);
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

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    await _syncProfileSilently();
    await _syncShareHandoffState();
    _isBootstrapping = false;
    notifyListeners();
  }

  Future<void> _syncProfileSilently() async {
    if (currentUser == null) return;

    try {
      await _authService.ensureProfile();
    } catch (e) {
      debugPrint('Profile sync skipped: $e');
    }
  }

  Future<void> _syncShareHandoffState() async {
    final userId = currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      await ShareHandoffService.instance.clear();
      return;
    }

    await ShareHandoffService.instance.syncAuthenticatedUser(userId);
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
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
