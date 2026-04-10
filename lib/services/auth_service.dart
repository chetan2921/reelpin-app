import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'profile_service.dart';
import 'supabase_client.dart';

class AuthService {
  AuthService(this._profileService);

  final ProfileService _profileService;

  Session? get currentSession => supabase.auth.currentSession;
  User? get currentUser => supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

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
}
