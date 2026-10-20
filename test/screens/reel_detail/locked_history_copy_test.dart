import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/remote_config/remote_config_service.dart';
import 'package:reelpin/view_models/remote_config_view_model.dart';

const _upgradeLine = 'Upgrade to Pro to open older saves again.';

Future<void> _pumpLockedReel(
  WidgetTester tester, {
  required Map<String, dynamic> remoteDocument,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final remoteConfig = RemoteConfigViewModel(
    RemoteConfigService(
      url: 'https://config.example.com/reelpin.json',
      client: MockClient(
        (_) async => http.Response(jsonEncode(remoteDocument), 200),
      ),
    ),
    loadBuildNumber: () async => 20,
  );
  await tester.runAsync(remoteConfig.start);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_HistoryLockedApiClient()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        remoteConfigViewModelProvider.overrideWith((ref) => remoteConfig),
      ],
      child: const MaterialApp(home: ReelDetailScreen(reel: _reel)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a hidden paywall drops the upgrade line on a locked reel', (
    tester,
  ) async {
    await _pumpLockedReel(tester, remoteDocument: const {});

    expect(find.text('FULL HISTORY IS PRO'), findsOneWidget);
    expect(find.textContaining(_upgradeLine), findsNothing);
    expect(find.text('VIEW PRO'), findsNothing);
  });

  testWidgets('paywall_visible keeps the upgrade line and the button', (
    tester,
  ) async {
    await _pumpLockedReel(tester, remoteDocument: {'paywall_visible': true});

    expect(find.textContaining(_upgradeLine), findsOneWidget);
    expect(find.text('VIEW PRO'), findsOneWidget);
  });
}

const _reel = Reel(
  id: 'reel-1',
  userId: 'user-123',
  url: 'https://www.instagram.com/reel/abc/',
  title: 'Coffee crawl',
  summary: 'A guide to coffee shops',
  caption: '',
  transcript: '',
  category: 'Travel',
  subCategory: 'Coffee Shops',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-20T00:00:00Z',
);

class _HistoryLockedApiClient extends ApiClient {
  _HistoryLockedApiClient() : super(baseUrl: 'https://example.com');

  @override
  Future<Reel> getReel(String reelId) async {
    throw const ApiException(
      'Upgrade required',
      402,
      errorCode: 'history_upgrade_required',
    );
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}
}
