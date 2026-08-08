import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _FakeRepository repository;
  late HomeViewModel vm;

  setUp(() {
    repository = _FakeRepository();
    vm = HomeViewModel(repository);
  });

  test('starts with no filters applied', () {
    expect(vm.selectedPlatform, isNull);
    expect(vm.selectedCategory, isNull);
    expect(vm.selectedSubcategory, isNull);
    expect(vm.hasActiveFilters, isFalse);
  });

  test('applyFilters sends all three levels to the repository', () async {
    vm.applyFilters(
      platform: 'instagram',
      category: 'Food',
      subcategory: 'Street Food',
    );
    await pumpEventQueue();

    expect(vm.selectedPlatform, 'instagram');
    expect(vm.hasActiveFilters, isTrue);
    expect(repository.lastInitialPlatform, 'instagram');
    expect(repository.lastInitialCategory, 'Food');
    expect(repository.lastInitialSubcategory, 'Street Food');
  });

  test('a platform on its own is enough to count as filtered', () async {
    vm.applyFilters(platform: 'youtube');
    await pumpEventQueue();

    expect(vm.hasActiveFilters, isTrue);
    expect(repository.lastInitialPlatform, 'youtube');
    expect(repository.lastInitialCategory, isNull);
  });

  test('the category row refines the platform instead of replacing it', () async {
    vm.applyFilters(platform: 'instagram');
    await pumpEventQueue();

    vm.filterByCategory('Food');
    await pumpEventQueue();

    // Tapping a category chip must not silently widen the filter back out to
    // every platform.
    expect(vm.selectedPlatform, 'instagram');
    expect(vm.selectedCategory, 'Food');
    expect(repository.lastInitialPlatform, 'instagram');
    expect(repository.lastInitialCategory, 'Food');
  });

  test('re-tapping the active category clears it but keeps the platform', () async {
    vm.applyFilters(platform: 'instagram', category: 'Food');
    await pumpEventQueue();

    vm.filterByCategory('Food');
    await pumpEventQueue();

    expect(vm.selectedCategory, isNull);
    expect(vm.selectedPlatform, 'instagram');
  });

  test('pagination carries the platform filter', () async {
    vm.applyFilters(platform: 'reddit', category: 'Movies');
    await pumpEventQueue();

    await vm.loadMoreReels();

    expect(repository.lastMorePlatform, 'reddit');
    expect(repository.lastMoreCategory, 'Movies');
  });

  test('clearFilters drops every level', () async {
    vm.applyFilters(
      platform: 'x',
      category: 'Sports',
      subcategory: 'Tennis',
    );
    await pumpEventQueue();

    vm.clearFilters();
    await pumpEventQueue();

    expect(vm.hasActiveFilters, isFalse);
    expect(repository.lastInitialPlatform, isNull);
    expect(repository.lastInitialCategory, isNull);
    expect(repository.lastInitialSubcategory, isNull);
  });

  test('reset drops the platform along with the rest', () async {
    vm.applyFilters(platform: 'pinterest', category: 'Fashion');
    await pumpEventQueue();

    vm.reset();

    expect(vm.selectedPlatform, isNull);
    expect(vm.selectedCategory, isNull);
    expect(vm.hasActiveFilters, isFalse);
  });
}

class _FakeRepository extends ReelRepository {
  _FakeRepository() : super(_FakeApiService(), _FakeAuthService());

  String? lastInitialPlatform;
  String? lastInitialCategory;
  String? lastInitialSubcategory;
  String? lastMorePlatform;
  String? lastMoreCategory;

  @override
  bool get hasMoreReels => true;

  @override
  Future<void> loadInitialReels({
    bool forceRefresh = false,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    lastInitialPlatform = platform;
    lastInitialCategory = category;
    lastInitialSubcategory = subcategory;
  }

  @override
  Future<void> loadMoreReels({
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? sort,
  }) async {
    lastMorePlatform = platform;
    lastMoreCategory = category;
  }

  @override
  List<Reel> get cachedReels => const [];
}

class _FakeApiService extends ApiClient {
  _FakeApiService() : super(baseUrl: 'https://example.com');

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
    return const ReelPage(
      reels: [],
      hasMore: false,
      totalCount: 0,
      limit: 25,
      offset: 0,
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
