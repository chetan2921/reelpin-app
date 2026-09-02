import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/app_entry.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/http/mock_collections_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/reelpin_app.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/how_to_guide_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/sharing/pending_deep_link.dart';
import 'package:reelpin/services/sharing/shared_collection_prefetch.dart';
import 'package:reelpin/view_models/session_view_model.dart';

void main() {
  testWidgets('App renders setup screen when Supabase is not configured', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: ReelPinApp(isSupabaseConfigured: false)),
    );
    expect(find.text('SUPABASE SETUP REQUIRED'), findsOneWidget);
  });

  testWidgets('onboarding completion persists across cold starts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpAppEntry(tester);
    expect(
      find.text('SAVE THE FINDS FROM YOUR FEEDS INTO PLANS YOU CAN USE.'),
      findsOneWidget,
    );

    await tester.tap(find.text('NEXT'));
    await _pumpPageTransition(tester);
    await tester.tap(find.text('NEXT'));
    await _pumpPageTransition(tester);
    await tester.tap(find.text('CONTINUE TO LOGIN'));
    await tester.pump();

    expect(find.text('WELCOME BACK TO YOUR REEL ARCHIVE.'), findsOneWidget);

    await _pumpAppEntry(tester);
    expect(find.text('WELCOME BACK TO YOUR REEL ARCHIVE.'), findsOneWidget);
    expect(
      find.text('SAVE THE FINDS FROM YOUR FEEDS INTO PLANS YOU CAN USE.'),
      findsNothing,
    );
  });

  testWidgets('finishing onboarding arms the how-to walkthrough once', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpAppEntry(tester);
    await tester.tap(find.text('NEXT'));
    await _pumpPageTransition(tester);
    await tester.tap(find.text('NEXT'));
    await _pumpPageTransition(tester);
    await tester.tap(find.text('CONTINUE TO LOGIN'));
    await tester.pump();

    expect(await HowToGuideService.instance.takePendingGuide(), isTrue);
    // A second cold start is an update, not an install, so nothing is owed.
    await _pumpAppEntry(tester);
    expect(await HowToGuideService.instance.takePendingGuide(), isFalse);
  });

  testWidgets('reaches onboarding without a branding hold', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _sizeView(tester);

    await tester.pumpWidget(_appEntry());
    // Long enough for the onboarding preference to be read off disk, and far
    // short of the 1600ms hold that used to sit in front of it.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('SYNCING YOUR SAVED WORLD'), findsNothing);
    expect(
      find.text('SAVE THE FINDS FROM YOUR FEEDS INTO PLANS YOU CAN USE.'),
      findsOneWidget,
    );
  });

  testWidgets('a collection link prefetches on the way to the shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _sizeView(tester);
    await _capturePendingLink(tester, 'https://reelpin.in/c/splash-token');
    addTearDown(() {
      SharedCollectionPrefetch.take('splash-token');
    });

    var fetchedToken = '';
    await tester.pumpWidget(
      _appEntry(
        collectionsHttp: _RecordingCollectionsHttp((token) {
          fetchedToken = token;
        }),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SYNCING YOUR SAVED WORLD'), findsNothing);
    // The fetch is already in flight, rather than waiting for the shell.
    expect(fetchedToken, 'splash-token');
  });

  testWidgets('checks for an Android update on startup and resume', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1170, 2532);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    const channel = MethodChannel('de.ffuf.in_app_update/methods');
    var checkCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method != 'checkForUpdate') return null;
      checkCalls += 1;
      return <String, Object?>{
        'updateAvailability': 1,
        'immediateAllowed': false,
        'immediateAllowedPreconditions': <int>[],
        'flexibleAllowed': false,
        'flexibleAllowedPreconditions': <int>[],
        'availableVersionCode': 15,
        'installStatus': 0,
        'packageName': 'com.chetanjain.reelpin',
        'clientVersionStalenessDays': null,
        'updatePriority': 0,
      };
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    await _pumpAppEntry(tester);
    expect(checkCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(checkCalls, 2);
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _pumpPageTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void _sizeView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

/// Puts a launch URL where [PendingDeepLink] reads it, through the same channel
/// the plugin uses on a real cold start.
Future<void> _capturePendingLink(WidgetTester tester, String url) async {
  const channel = MethodChannel('com.llfbandit.app_links/messages');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => call.method == 'getInitialLink' ? url : null,
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    PendingDeepLink.take();
  });
  await PendingDeepLink.capture();
}

Widget _appEntry({MockCollectionsHttp? collectionsHttp}) {
  return ProviderScope(
    overrides: [
      sessionViewModelProvider.overrideWith(
        (ref) => _FakeSessionViewModel(_FakeAuthService()),
      ),
      if (collectionsHttp != null)
        collectionsHttpProvider.overrideWithValue(collectionsHttp),
    ],
    child: const MaterialApp(home: AppEntry()),
  );
}

Future<void> _pumpAppEntry(WidgetTester tester) async {
  await tester.pumpWidget(_appEntry());
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final hasOnboarding = find
        .text('SAVE THE FINDS FROM YOUR FEEDS INTO PLANS YOU CAN USE.')
        .evaluate()
        .isNotEmpty;
    final hasAuth = find
        .text('WELCOME BACK TO YOUR REEL ARCHIVE.')
        .evaluate()
        .isNotEmpty;
    if (hasOnboarding || hasAuth) return;
  }
}

class _FakeSessionViewModel extends SessionViewModel {
  _FakeSessionViewModel(AuthService authService)
    : super(
        authService,
        () => ApiClient(baseUrl: 'https://example.com'),
        () => ApiClient(baseUrl: 'https://example.com'),
      );
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

class _RecordingCollectionsHttp extends MockCollectionsHttp {
  _RecordingCollectionsHttp(this.onFetch);

  final void Function(String token) onFetch;

  @override
  Future<CollectionDetail> getSharedCollection(
    String token, {
    int limit = 25,
    int? offset,
  }) async {
    onFetch(token);
    return CollectionDetail(
      collection: CollectionSummary(id: 'id', name: token),
      reels: const [],
      pagination: const CollectionPagination(),
    );
  }
}
