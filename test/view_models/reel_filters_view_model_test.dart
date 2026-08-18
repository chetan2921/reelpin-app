import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _FakeRepository repository;
  late ReelFiltersViewModel vm;

  setUp(() {
    repository = _FakeRepository();
    vm = ReelFiltersViewModel(repository);
  });

  Future<void> load() => vm.loadFilters(forceRefresh: true);

  test('exposes the platforms in the order the backend sent them', () async {
    await load();

    expect(vm.platforms.map((group) => group.platform), [
      'instagram',
      'youtube',
    ]);
    expect(vm.hasPlatforms, isTrue);
    expect(vm.totalCount, 12);
    expect(vm.topPlatform, 'instagram');
  });

  test('categoriesFor scopes the list to one platform', () async {
    await load();

    expect(vm.categoriesFor('youtube').map((group) => group.category), [
      'Travel',
    ]);
    expect(vm.categoriesFor('instagram').map((group) => group.category), [
      'Movies',
      'Travel',
    ]);
  });

  test('categoriesFor falls back to the aggregate with no platform', () async {
    await load();

    expect(vm.categoriesFor(null).map((group) => group.category), [
      'Travel',
      'Movies',
    ]);
  });

  test(
    'an unknown platform offers no categories rather than all of them',
    () async {
      await load();

      expect(vm.categoriesFor('linkedin'), isEmpty);
    },
  );

  test('previewCountFor resolves every level from the tree', () async {
    await load();

    expect(vm.previewCountFor(), 12);
    expect(vm.previewCountFor(platform: 'instagram'), 8);
    expect(vm.previewCountFor(platform: 'instagram', category: 'Movies'), 6);
    expect(
      vm.previewCountFor(
        platform: 'instagram',
        category: 'Movies',
        subcategory: 'Trailers',
      ),
      4,
    );
  });

  test('previewCountFor uses the aggregate when no platform is set', () async {
    await load();

    // Travel spans both platforms: 2 on Instagram plus 4 on YouTube.
    expect(vm.previewCountFor(category: 'Travel'), 6);
  });

  test('a combination with nothing behind it previews as zero', () async {
    await load();

    expect(vm.previewCountFor(platform: 'youtube', category: 'Movies'), 0);
    expect(vm.previewCountFor(platform: 'linkedin'), 0);
    expect(
      vm.previewCountFor(
        platform: 'instagram',
        category: 'Movies',
        subcategory: 'Bloopers',
      ),
      0,
    );
  });

  test('an error leaves the tree empty and surfaces a message', () async {
    repository.shouldFail = true;

    await load();

    expect(vm.error, isNotNull);
    expect(vm.hasPlatforms, isFalse);
    expect(vm.totalCount, 0);
    // With no tree, the sheet must not claim a preview count it cannot back up.
    expect(vm.previewCountFor(platform: 'instagram'), 0);
  });

  test('reset clears the tree', () async {
    await load();
    expect(vm.hasPlatforms, isTrue);

    vm.reset();

    expect(vm.hasPlatforms, isFalse);
    expect(vm.response, isNull);
  });
}

class _FakeRepository extends ReelRepository {
  _FakeRepository() : super(_FakeApiService(), _FakeAuthService());

  bool shouldFail = false;

  @override
  Future<ReelFiltersResponse> getFilters({
    String? platform,
    String? category,
    String? subcategory,
  }) async {
    if (shouldFail) throw Exception('offline');
    return ReelFiltersResponse.fromJson(_treeJson);
  }
}

const _treeJson = <String, dynamic>{
  'total_count': 12,
  'top_platform': 'instagram',
  'selected_preview_count': 12,
  'platforms': [
    {
      'platform': 'instagram',
      'label': 'Instagram',
      'count': 8,
      'top_category': 'Movies',
      'categories': [
        {
          'category': 'Movies',
          'label': 'Movies',
          'count': 6,
          'subcategories': [
            {'name': 'Trailers', 'label': 'Trailers', 'count': 4},
            {'name': 'Reviews', 'label': 'Reviews', 'count': 2},
          ],
        },
        {
          'category': 'Travel',
          'label': 'Travel',
          'count': 2,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 2},
          ],
        },
      ],
    },
    {
      'platform': 'youtube',
      'label': 'YouTube',
      'count': 4,
      'top_category': 'Travel',
      'categories': [
        {
          'category': 'Travel',
          'label': 'Travel',
          'count': 4,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 4},
          ],
        },
      ],
    },
  ],
  'categories': [
    {
      'category': 'Travel',
      'label': 'Travel',
      'count': 6,
      'subcategories': [
        {'name': 'Food Guides', 'label': 'Food Guides', 'count': 6},
      ],
    },
    {
      'category': 'Movies',
      'label': 'Movies',
      'count': 6,
      'subcategories': [
        {'name': 'Trailers', 'label': 'Trailers', 'count': 4},
        {'name': 'Reviews', 'label': 'Reviews', 'count': 2},
      ],
    },
  ],
};

class _FakeApiService extends ApiClient {
  _FakeApiService() : super(baseUrl: 'https://example.com');
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
