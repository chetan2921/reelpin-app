import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/mock_collections_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/app_shell/app_shell.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/sharing/pending_deep_link.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

void main() {
  final cases = <String, (Object, String)>{
    'unknown invite': (
      const ApiException(
        'This invite is no longer valid.',
        400,
        errorCode: 'collection_invite_invalid',
      ),
      'This invite is no longer valid.',
    ),
    'expired invite': (
      const ApiException(
        'This invite has expired.',
        410,
        errorCode: 'invite_expired',
      ),
      'This invite has expired.',
    ),
    'authentication failure': (
      const ApiException('Please sign in again.', 401),
      'Please sign in again.',
    ),
    'connection failure': (
      const ApiException('Could not connect. Please try again.', 503),
      'Could not connect. Please try again.',
    ),
    'technical server error': (
      const ApiException(
        'Internal server error at https://private.example',
        500,
      ),
      'Could not join this collection right now.',
    ),
    'unexpected failure': (
      StateError('private failure details'),
      'Could not join this collection right now.',
    ),
  };

  testWidgets('cold and warm invites preserve useful error messages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_shell_initial_permissions_prompted_v6': true,
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? initialUrl;
    var isListening = false;
    const links = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      links,
      (call) async => call.method == 'getInitialLink' ? initialUrl : null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(events, (
      call,
    ) async {
      if (call.method == 'listen') isListening = true;
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method != 'create') return null;
        final id = (call.arguments as Map)['id'];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel('plugins.flutter.io/google_maps_$id'),
          (call) async =>
              call.method == 'map#waitForMap' ? Completer<void>().future : null,
        );
        return 0;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        links,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        events,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      );
      PendingDeepLink.take();
    });

    final warmInvites = _FailingInvites(cases.values.first.$1);
    await _pumpShell(tester, warmInvites);
    for (var frame = 0; !isListening && frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(isListening, isTrue);
    for (final entry in cases.entries) {
      warmInvites.error = entry.value.$1;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.llfbandit.app_links/events',
        const StandardMethodCodec().encodeSuccessEnvelope(
          'https://reelpin.in/c/invite/test-token',
        ),
        (_) {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(entry.value.$2), findsOneWidget, reason: entry.key);
      if (entry.key != 'unknown invite') {
        expect(find.text('This invite is no longer valid.'), findsNothing);
      }
      final context = tester.element(find.byType(AppShell));
      ScaffoldMessenger.of(context).clearSnackBars();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(warmInvites.accepted, List.filled(cases.length, 'test-token'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    initialUrl = 'https://reelpin.in/c/invite/test-token';
    for (final entry in cases.entries) {
      await PendingDeepLink.capture();
      final invites = _FailingInvites(entry.value.$1);
      await _pumpShell(tester, invites);
      await tester.pump(const Duration(milliseconds: 300));
      expect(invites.accepted, ['test-token']);
      expect(find.text(entry.value.$2), findsOneWidget, reason: entry.key);
      if (entry.key != 'unknown invite') {
        expect(find.text('This invite is no longer valid.'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _pumpShell(WidgetTester tester, _FailingInvites invites) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(_SignedInAuth()),
        apiClientProvider.overrideWithValue(
          ApiClient(
            baseUrl: 'https://api.example',
            accessTokenProvider: () => 'test-token',
            client: MockClient((_) async => http.Response('{}', 503)),
          ),
        ),
        collectionsViewModelProvider.overrideWith(
          (_) => CollectionsViewModel(invites),
        ),
      ],
      child: const MaterialApp(home: AppShell()),
    ),
  );
  await tester.pump();
}

class _FailingInvites extends MockCollectionsHttp {
  _FailingInvites(this.error);

  Object error;
  final accepted = <String>[];

  @override
  Future<List<CollectionSummary>> getCollections() async => [];

  @override
  Future<CollectionSummary> acceptCollectionInvite(String token) async {
    accepted.add(token);
    throw error;
  }
}

class _SignedInAuth extends AuthService {
  _SignedInAuth() : super(ProfileService());

  @override
  User? get currentUser => const User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> ensureProfile() async {}
}
