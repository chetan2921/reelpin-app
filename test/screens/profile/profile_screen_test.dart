import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/profile/profile_screen.dart';
import 'package:reelpin/view_models/session_view_model.dart';

void main() {
  for (final completeBeforeSwitch in [false, true]) {
    testWidgets('profile stats do not survive an account change: $completeBeforeSwitch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(locationChannel, (_) async => false);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(locationChannel, null);
      });
      final session = _Session();
      final api = _AccountApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionViewModelProvider.overrideWith((ref) => session),
            accountHttpProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
      expect(api.calls, 1);
      if (completeBeforeSwitch) {
        api.first.complete(_stats);
        await tester.pump();
        expect(find.text('777'), findsOneWidget);
      }

      session.switchUser();
      await tester.pump();
      if (!completeBeforeSwitch) api.first.complete(_stats);
      await tester.pump();

      expect(find.text('777'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

const _stats = LibraryStats(
  totalReels: 777,
  totalPinnedLocations: 0,
  totalTags: 0,
  totalCategories: 0,
  totalSubcategories: 0,
);

class _AccountApi extends ApiClient {
  final first = Completer<LibraryStats>();
  final next = Completer<LibraryStats>();
  int calls = 0;

  @override
  Future<LibraryStats> getLibraryStats() {
    calls += 1;
    return calls == 1 ? first.future : next.future;
  }
}

class _Session extends ChangeNotifier implements SessionViewModel {
  String _userId = 'user-a';

  void switchUser() {
    _userId = 'user-b';
    notifyListeners();
  }

  @override
  User get currentUser => User.fromJson({
    'id': _userId,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-10-28T00:00:00Z',
  });

  @override
  String get displayName => _userId;
  @override
  String get email => '$_userId@example.com';
  @override
  String get initials => 'RP';
  @override
  bool get isBusy => false;
  @override
  bool get isSigningOut => false;
  @override
  bool get isDeletingAccount => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
