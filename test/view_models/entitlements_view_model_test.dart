import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/http/account_http.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/discover_view_model.dart';
import 'package:reelpin/view_models/entitlements_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:reelpin/view_models/search_view_model.dart';

/// Holds each entitlements request open until the test releases it, and
/// records whether it asked the backend to sync. Every request then fails,
/// which keeps the view model away from the content view models below.
class _GatedAccountHttp implements AccountHttp {
  final List<bool> syncs = [];
  final List<Completer<void>> gates = [];

  @override
  Future<EntitlementsResponse> getAccountEntitlements({
    required String userId,
    bool sync = false,
  }) async {
    syncs.add(sync);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    throw Exception('released');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedInAuth extends AuthService {
  _SignedInAuth() : super(ProfileService());

  @override
  User? get currentUser => const User(
    id: 'user-1',
    appMetadata: <String, dynamic>{},
    userMetadata: <String, dynamic>{},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
}

class _UnusedRepository implements ReelRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedHome implements HomeViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedMap implements MapViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedFilters implements ReelFiltersViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedDiscover implements DiscoverViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSearch implements SearchViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  EntitlementsViewModel build(AccountHttp http) => EntitlementsViewModel(
    http,
    _SignedInAuth(),
    _UnusedRepository(),
    _UnusedHome(),
    _UnusedMap(),
    _UnusedFilters(),
    _UnusedDiscover(),
    _UnusedSearch(),
  );

  test('a purchase made during a refresh still syncs right after it', () async {
    final http = _GatedAccountHttp();
    final viewModel = build(http);

    final startup = viewModel.refresh();
    // The purchase lands while the startup refresh is still waiting.
    unawaited(viewModel.refresh(syncBilling: true));
    await pumpEventQueue();
    expect(http.syncs, [false]);

    http.gates.first.complete();
    await startup;
    await pumpEventQueue();
    expect(http.syncs, [false, true]);

    http.gates.last.complete();
    await pumpEventQueue();
  });

  test('a plain refresh never asks the backend to sync', () async {
    final http = _GatedAccountHttp();
    final viewModel = build(http);

    final refresh = viewModel.refresh(reloadContent: true);
    await pumpEventQueue();
    http.gates.single.complete();
    await refresh;
    await pumpEventQueue();

    expect(http.syncs, [false]);
  });
}
