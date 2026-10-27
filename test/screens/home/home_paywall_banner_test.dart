import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/home/home_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/remote_config/remote_config_service.dart';
import 'package:reelpin/view_models/remote_config_view_model.dart';

const _bannerText = 'FREE ACCOUNT ACCESS';

Future<void> _pumpFreeHome(
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FreePlanApiClient()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        remoteConfigViewModelProvider.overrideWith((ref) => remoteConfig),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
  );
  await tester.runAsync(() async {
    await remoteConfig.start();
    await container.read(entitlementsViewModelProvider).refresh();
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the free-plan banner stays hidden by default', (tester) async {
    await _pumpFreeHome(tester, remoteDocument: const {});

    expect(find.text(_bannerText), findsNothing);
  });

  testWidgets('paywall_visible brings the free-plan banner back', (
    tester,
  ) async {
    await _pumpFreeHome(tester, remoteDocument: {'paywall_visible': true});

    expect(find.text(_bannerText), findsOneWidget);
  });
}

class _FreePlanApiClient extends ApiClient {
  _FreePlanApiClient() : super(baseUrl: 'https://example.com');

  @override
  Future<EntitlementsResponse> getAccountEntitlements({
    required String userId,
  }) async {
    return EntitlementsResponse.fromJson({
      'user_id': userId,
      'current_entitlement': {
        'plan': 'free',
        'subscription_status': 'active',
        'is_premium': false,
        'restricted': false,
      },
      'usage': {'saved_reels': 3},
      'limits': {'saved_reels': 20},
      'features': const <String, dynamic>{},
    });
  }

  @override
  Future<ReelPage> getReelsPage({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 50,
    String? sort,
  }) async {
    return const ReelPage(reels: [], limit: 25);
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => User.fromJson({
    'id': 'user-123',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-04-20T00:00:00Z',
  });

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}
}
