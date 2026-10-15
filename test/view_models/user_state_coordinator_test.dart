import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/http/collections_http.dart';
import 'package:reelpin/providers.dart';

/// The coordinator is what runs when the signed-in user changes, so anything it
/// skips is still on screen for the next account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a user change clears the previous account\'s collections', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        collectionsHttpProvider.overrideWithValue(_FakeCollectionsHttp()),
      ],
    );
    addTearDown(container.dispose);
    final collections = container.read(collectionsViewModelProvider);
    await collections.loadCollections();
    expect(collections.collections, isNotEmpty);

    container.read(userStateCoordinatorProvider).reset();

    expect(collections.collections, isEmpty);
  });
}

class _FakeCollectionsHttp implements CollectionsHttp {
  @override
  Future<List<CollectionSummary>> getCollections() async => const [
    CollectionSummary(id: 'a', name: 'Tokyo Food Crawl', role: 'viewer'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
