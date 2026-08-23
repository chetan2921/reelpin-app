import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/account_http.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/session_view_model.dart';
import 'package:reelpin/http/sharing_http.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attempts push deactivation before revoking and signing out', () async {
    SharedPreferences.setMockInitialValues({});
    final events = <String>[];
    final authService = _FakeAuthService(events);
    final sharingHttp = _FakeSharingHttp(events);
    final viewModel = SessionViewModel(
      authService,
      ApiClient.new,
      () => sharingHttp,
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
      ApiClient.new,
      () => _FakeSharingHttp(events),
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

  test('deactivates push only after account deletion succeeds', () async {
    SharedPreferences.setMockInitialValues({});
    final events = <String>[];
    final viewModel = SessionViewModel(
      _FakeAuthService(events),
      () => _FakeAccountHttp(events),
      () => _FakeSharingHttp(events),
      unregisterPushToken: () async => events.add('unregister-push'),
    );

    expect(await viewModel.deleteAccount(), isTrue);
    expect(events, ['delete-account', 'unregister-push', 'supabase-sign-out']);
    viewModel.dispose();
  });

  test('starts the profile sync without waiting out a startup delay', () async {
    SharedPreferences.setMockInitialValues({});
    final events = <String>[];
    final viewModel = SessionViewModel(
      _FakeAuthService(events, user: _signedInUser),
      ApiClient.new,
      () => _FakeSharingHttp(events),
    );

    // Only drains microtasks and zero-duration timers, so a startup
    // `Future.delayed` would still be pending here — which is the point. The
    // splash used to sit behind exactly that.
    await pumpEventQueue();

    expect(events, contains('ensure-profile'));
    viewModel.dispose();
  });

  test('keeps push registration when account deletion fails', () async {
    SharedPreferences.setMockInitialValues({});
    final events = <String>[];
    final viewModel = SessionViewModel(
      _FakeAuthService(events),
      () => _FakeAccountHttp(events, shouldFail: true),
      () => _FakeSharingHttp(events),
      unregisterPushToken: () async => events.add('unregister-push'),
    );

    expect(await viewModel.deleteAccount(), isFalse);
    expect(events, ['delete-account']);
    viewModel.dispose();
  });
}

const _signedInUser = User(
  id: 'user-1',
  appMetadata: <String, dynamic>{},
  userMetadata: <String, dynamic>{},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.events, {this.user}) : super(ProfileService());

  final List<String> events;
  final User? user;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {
    events.add('ensure-profile');
  }

  @override
  Future<void> signOut() async {
    events.add('supabase-sign-out');
  }
}

class _FakeSharingHttp implements SharingHttp {
  _FakeSharingHttp(this.events);

  final List<String> events;

  @override
  Future<void> revokeShareToken() async {
    events.add('revoke-share-token');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountHttp implements AccountHttp {
  _FakeAccountHttp(this.events, {this.shouldFail = false});

  final List<String> events;
  final bool shouldFail;

  @override
  Future<void> deleteAccount() async {
    events.add('delete-account');
    if (shouldFail) throw Exception('deletion failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
