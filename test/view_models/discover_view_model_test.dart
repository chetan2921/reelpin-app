import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/features/discover/domain/discover_response.dart';
import 'package:reelpin/features/reels/domain/reel.dart';
import 'package:reelpin/features/reels/domain/reel_page.dart';
import 'package:reelpin/features/reels/data/reel_repository.dart';
import 'package:reelpin/core/network/api_service.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/features/auth/data/profile_service.dart';
import 'package:reelpin/features/discover/presentation/discover_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('loadDiscover stores latest discover data from repository', () async {
    final repository = _FakeReelRepository(
      onDiscover: (_) async => _discoverResponse(recentSaves: [_reelA]),
    );
    final viewModel = DiscoverViewModel(repository);

    await viewModel.loadDiscover();

    expect(viewModel.discover?.recentSaves.map((reel) => reel.id), ['reel-a']);
    expect(viewModel.discoverError, isNull);
    expect(repository.discoverCalls, 1);
  });

  test('selected saved date is passed to discover reloads', () async {
    final repository = _FakeReelRepository(
      onDiscover: (savedDate) async =>
          _discoverResponse(recentSaves: const [], selectedDate: savedDate),
    );
    final viewModel = DiscoverViewModel(repository);

    await viewModel.selectSavedDate(
      const SavedDateOption(value: '2026-04-20', label: 'Apr 20'),
    );

    expect(repository.lastSavedDate, '2026-04-20');
    expect(viewModel.selectedSavedDate, '2026-04-20');
    expect(viewModel.selectedSavedDateLabel, 'Apr 20');
  });

  test(
    'latest discover response wins when earlier requests finish late',
    () async {
      final first = Completer<DiscoverResponse>();
      final second = Completer<DiscoverResponse>();
      var callCount = 0;
      final repository = _FakeReelRepository(
        onDiscover: (_) {
          callCount += 1;
          return callCount == 1 ? first.future : second.future;
        },
      );
      final viewModel = DiscoverViewModel(repository);

      unawaited(viewModel.loadDiscover());
      await Future<void>.delayed(Duration.zero);
      unawaited(viewModel.loadDiscover(forceRefresh: true));
      await Future<void>.delayed(Duration.zero);

      second.complete(_discoverResponse(recentSaves: [_reelB]));
      await Future<void>.delayed(Duration.zero);
      first.complete(_discoverResponse(recentSaves: [_reelA]));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.discover?.recentSaves.single.id, 'reel-b');
    },
  );

  test('openCategory loads reels for the selected category', () async {
    final repository = _FakeReelRepository(
      onReelsPage: ({required category, required limit}) async {
        return ReelPage(
          reels: const [_reelB],
          hasMore: false,
          totalCount: 1,
          limit: limit,
          offset: 0,
        );
      },
    );
    final viewModel = DiscoverViewModel(repository);

    await viewModel.openCategory(
      const DiscoverCategory(category: 'Travel', label: 'Travel', count: 4),
    );

    expect(repository.lastCategory, 'Travel');
    expect(repository.lastLimit, 4);
    expect(viewModel.selectedCategory, 'Travel');
    expect(viewModel.categoryReelsPage?.reels.single.id, 'reel-b');
  });

  test('removeReel drops stale discover and category items locally', () async {
    final repository = _FakeReelRepository(
      onDiscover: (_) async => _discoverResponse(recentSaves: [_reelA, _reelB]),
      onReelsPage: ({required category, required limit}) async {
        return const ReelPage(
          reels: [_reelA, _reelB],
          hasMore: false,
          totalCount: 2,
          limit: 2,
          offset: 0,
        );
      },
    );
    final viewModel = DiscoverViewModel(repository);

    await viewModel.loadDiscover();
    await viewModel.openCategory(
      const DiscoverCategory(category: 'Food', label: 'Food', count: 2),
    );
    viewModel.removeReel('reel-a');

    expect(viewModel.discover?.recentSaves.map((reel) => reel.id), ['reel-b']);
    expect(viewModel.categoryReelsPage?.reels.map((reel) => reel.id), [
      'reel-b',
    ]);
    expect(viewModel.categoryReelsPage?.totalCount, 1);
  });
}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository({this.onDiscover, this.onReelsPage})
    : super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

  final Future<DiscoverResponse> Function(String? savedDate)? onDiscover;
  final Future<ReelPage> Function({
    required String category,
    required int limit,
  })?
  onReelsPage;

  int discoverCalls = 0;
  String? lastSavedDate;
  String? lastCategory;
  int? lastLimit;

  @override
  Future<DiscoverResponse> getDiscover({
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 25,
  }) {
    discoverCalls += 1;
    lastSavedDate = savedDate;
    final handler = onDiscover;
    if (handler != null) {
      return handler(savedDate);
    }
    return Future.value(_discoverResponse(recentSaves: const []));
  }

  @override
  Future<ReelPage> getReelsPage({
    String? category,
    String? subcategory,
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 25,
    String? sort,
  }) {
    lastCategory = category;
    lastLimit = limit;
    final handler = onReelsPage;
    if (handler != null) {
      return handler(category: category ?? '', limit: limit);
    }
    return Future.value(
      ReelPage(
        reels: const [],
        hasMore: false,
        totalCount: 0,
        limit: limit,
        offset: 0,
      ),
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

DiscoverResponse _discoverResponse({
  required List<Reel> recentSaves,
  String? selectedDate,
}) {
  return DiscoverResponse(
    recentSaves: recentSaves,
    recentSavesCount: recentSaves.length,
    savedDates: const [SavedDateOption(value: '2026-04-20', label: 'Apr 20')],
    reelsForSelectedDate: selectedDate == null ? const [] : recentSaves,
    categoryGrid: const [
      DiscoverCategory(category: 'Food', label: 'Food', count: 2),
      DiscoverCategory(category: 'Travel', label: 'Travel', count: 1),
    ],
    quickSearchPrompts: const ['coffee'],
    pagination: const DiscoverPagination(hasMore: false, limit: 25, offset: 0),
    selectedDate: selectedDate,
  );
}

const _reelA = Reel(
  id: 'reel-a',
  userId: 'user-123',
  url: 'https://example.com/a',
  title: 'A',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Food',
  subCategory: 'Meals',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-20T00:00:00Z',
);

const _reelB = Reel(
  id: 'reel-b',
  userId: 'user-123',
  url: 'https://example.com/b',
  title: 'B',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Travel',
  subCategory: 'Trips',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
  createdAt: '2026-04-19T00:00:00Z',
);
