import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/core/network/api_service.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/features/auth/data/profile_service.dart';
import 'package:reelpin/features/auth/presentation/session_viewmodel.dart';
import 'package:reelpin/features/sharing/data/sharing_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attempts push deactivation before revoking and signing out', () async {
    SharedPreferences.setMockInitialValues({});
    final events = <String>[];
    final authService = _FakeAuthService(events);
    final sharingApi = _FakeSharingApi(events);
    final viewModel = SessionViewModel(
      authService,
      ApiService.new,
      () => sharingApi,
      unregisterPushToken: () async => events.add('unregister-push'),
    );

    await viewModel.signOut();

    expect(events.take(3), [
      'unregister-push',
      'revoke-share-token',
      'supabase-sign-out',
    ]);
    viewModel.dispose();
  });

  test('continues signing out when push deactivation fails', () async {
    SharedPreferences.setMockInitialValues({});
    final events = <String>[];
    final viewModel = SessionViewModel(
      _FakeAuthService(events),
      ApiService.new,
      () => _FakeSharingApi(events),
      unregisterPushToken: () async {
        events.add('unregister-push');
        throw Exception('network unavailable');
      },
    );

    await viewModel.signOut();

    expect(
      events,
      containsAllInOrder([
        'unregister-push',
        'revoke-share-token',
        'supabase-sign-out',
      ]),
    );
    viewModel.dispose();
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.events) : super(ProfileService());

  final List<String> events;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}

  @override
  Future<void> signOut() async {
    events.add('supabase-sign-out');
  }
}

class _FakeSharingApi implements SharingApi {
  _FakeSharingApi(this.events);

  final List<String> events;

  @override
  Future<void> revokeShareToken() async {
    events.add('revoke-share-token');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
