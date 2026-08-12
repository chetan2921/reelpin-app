import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/collections_http.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

void main() {
  group('loading', () {
    test('loadCollections populates and clears the loading flag', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a'), _summary('b')]);
      final vm = CollectionsViewModel(api);

      final future = vm.loadCollections();
      expect(vm.isLoadingCollections, isTrue);
      await future;

      expect(vm.isLoadingCollections, isFalse);
      expect(vm.collections.map((c) => c.id), ['a', 'b']);
      expect(vm.collectionsError, isNull);
      expect(api.getCollectionsCalls, 1);
    });

    test('a second load is served from cache unless forced', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);

      await vm.loadCollections();
      await vm.loadCollections();
      expect(api.getCollectionsCalls, 1);

      await vm.loadCollections(forceRefresh: true);
      expect(api.getCollectionsCalls, 2);
    });

    test('concurrent loads share one in-flight request', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);

      await Future.wait([vm.loadCollections(), vm.loadCollections()]);

      expect(api.getCollectionsCalls, 1);
    });

    test('a failure surfaces a user-facing message, not an exception', () async {
      final api = _FakeCollectionsHttp(
        error: const ApiException('Could not load collections right now.', 500),
      );
      final vm = CollectionsViewModel(api);

      await vm.loadCollections();

      expect(vm.collectionsError, isNotNull);
      expect(vm.isLoadingCollections, isFalse);
      expect(vm.collections, isEmpty);
    });

    test('detail is cached per id and refetched on force', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);

      await vm.loadCollectionDetail('a');
      await vm.loadCollectionDetail('a');
      expect(api.detailCalls, 1);
      expect(vm.detailFor('a')?.collection.id, 'a');

      await vm.loadCollectionDetail('a', forceRefresh: true);
      expect(api.detailCalls, 2);
    });
  });

  group('pagination', () {
    test('loadMore appends the next page and keeps the new cursor', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      api.detailQueue.addAll([
        _detail('a', reelIds: ['r1', 'r2'], hasMore: true, nextOffset: 2),
        _detail('a', reelIds: ['r3'], hasMore: false),
      ]);
      final vm = CollectionsViewModel(api);

      await vm.loadCollectionDetail('a');
      expect(vm.detailFor('a')?.reels.map((r) => r.id), ['r1', 'r2']);

      await vm.loadMore('a');

      expect(vm.detailFor('a')?.reels.map((r) => r.id), ['r1', 'r2', 'r3']);
      expect(vm.detailFor('a')?.pagination.hasMore, isFalse);
    });

    test('loadMore is a no-op when there is no next page', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      api.detailQueue.add(_detail('a', reelIds: ['r1'], hasMore: false));
      final vm = CollectionsViewModel(api);

      await vm.loadCollectionDetail('a');
      final before = api.detailCalls;
      await vm.loadMore('a');

      expect(api.detailCalls, before);
    });
  });

  group('mutations', () {
    test('createCollection puts the new collection first', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();

      final created = await vm.createCollection(name: 'Fresh');

      expect(created?.id, 'created');
      expect(vm.collections.first.id, 'created');
      expect(vm.collections.map((c) => c.id), ['created', 'a']);
    });

    test('deleteCollection drops it from the list and the detail cache', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a'), _summary('b')]);
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();
      await vm.loadCollectionDetail('a');

      await vm.deleteCollection('a');

      expect(vm.collections.map((c) => c.id), ['b']);
      expect(vm.detailFor('a'), isNull);
    });

    test('removeReel drops the reel and decrements the count', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a', itemCount: 2)]);
      api.detailQueue.add(
        _detail('a', reelIds: ['r1', 'r2'], itemCount: 2),
      );
      final vm = CollectionsViewModel(api);
      await vm.loadCollectionDetail('a');

      await vm.removeReel(collectionId: 'a', reelId: 'r1');

      expect(vm.detailFor('a')?.reels.map((r) => r.id), ['r2']);
      expect(vm.detailFor('a')?.collection.itemCount, 1);
    });

    test('removeReel never drives the count below zero', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      api.detailQueue.add(_detail('a', reelIds: ['r1'], itemCount: 0));
      final vm = CollectionsViewModel(api);
      await vm.loadCollectionDetail('a');

      await vm.removeReel(collectionId: 'a', reelId: 'r1');

      expect(vm.detailFor('a')?.collection.itemCount, 0);
    });

    test('addReels refreshes both the detail and the list', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();
      await vm.loadCollectionDetail('a');
      final detailBefore = api.detailCalls;
      final listBefore = api.getCollectionsCalls;

      final added = await vm.addReels(
        collectionId: 'a',
        reelIds: const ['r9'],
      );

      expect(added, 1);
      expect(api.detailCalls, greaterThan(detailBefore));
      expect(api.getCollectionsCalls, greaterThan(listBefore));
    });

    test('isMutating is reset even when the call throws', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      api.mutationError = const ApiException('nope', 403);
      final vm = CollectionsViewModel(api);

      await expectLater(vm.deleteCollection('a'), throwsA(isA<ApiException>()));
      expect(vm.isMutating, isFalse);
    });
  });

  group('sharing', () {
    test('enableLink flips visibility in the list and the detail', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();
      await vm.loadCollectionDetail('a');

      final link = await vm.enableLink('a');

      expect(link?.token, 'tok-a');
      expect(vm.collections.single.visibility, 'link');
      expect(vm.collections.single.hasLink, isTrue);
      expect(vm.detailFor('a')?.collection.hasLink, isTrue);
    });

    test('disableLink flips it back to private', () async {
      final api = _FakeCollectionsHttp(
        collections: [_summary('a', visibility: 'link')],
      );
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();
      await vm.loadCollectionDetail('a');

      await vm.disableLink('a');

      expect(vm.collections.single.visibility, 'private');
      expect(vm.detailFor('a')?.collection.hasLink, isFalse);
    });

    test('acceptInvite adds the joined collection to the list', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();

      final joined = await vm.acceptInvite('inv-1');

      expect(joined?.id, 'joined');
      expect(joined?.role, 'editor');
      expect(vm.collections.map((c) => c.id), contains('joined'));
    });

    test('leave removes it from the list and the detail cache', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a'), _summary('b')]);
      final vm = CollectionsViewModel(api);
      await vm.loadCollections();
      await vm.loadCollectionDetail('a');

      await vm.leave('a');

      expect(vm.collections.map((c) => c.id), ['b']);
      expect(vm.detailFor('a'), isNull);
    });

    test('loadMembers swallows a failure and returns null', () async {
      final api = _FakeCollectionsHttp(collections: [_summary('a')]);
      api.membersError = const ApiException('nope', 500);
      final vm = CollectionsViewModel(api);

      expect(await vm.loadMembers('a'), isNull);
    });
  });
}

// ─── Fixtures ───

CollectionSummary _summary(
  String id, {
  String visibility = 'private',
  int itemCount = 0,
}) {
  return CollectionSummary(
    id: id,
    name: 'Collection $id',
    visibility: visibility,
    itemCount: itemCount,
  );
}

Reel _reel(String id) => Reel.fromJson({
  'id': id,
  'user_id': 'user-1',
  'url': 'https://instagram.com/reel/$id',
  'title': 'Reel $id',
  'summary': '',
  'caption': '',
  'transcript': '',
  'category': 'Travel',
  'sub_category': '',
  'key_facts': const <String>[],
  'locations': const <Map<String, Object?>>[],
  'people_mentioned': const <String>[],
  'actionable_items': const <String>[],
  'created_at': '2026-05-23T00:00:00Z',
});

CollectionDetail _detail(
  String id, {
  List<String> reelIds = const [],
  bool hasMore = false,
  int? nextOffset,
  int itemCount = 0,
  String visibility = 'private',
}) {
  return CollectionDetail(
    collection: _summary(id, itemCount: itemCount, visibility: visibility),
    reels: reelIds.map(_reel).toList(),
    pagination: CollectionPagination(
      hasMore: hasMore,
      nextOffset: nextOffset,
      nextCursor: nextOffset?.toString(),
      totalCount: itemCount,
    ),
    canEdit: true,
  );
}

class _FakeCollectionsHttp implements CollectionsHttp {
  _FakeCollectionsHttp({this.collections = const [], this.error});

  final List<CollectionSummary> collections;
  final Object? error;
  Object? mutationError;
  Object? membersError;

  /// Consumed in order by getCollectionDetail; falls back to a bare detail.
  final List<CollectionDetail> detailQueue = [];

  int getCollectionsCalls = 0;
  int detailCalls = 0;

  @override
  Future<List<CollectionSummary>> getCollections() async {
    getCollectionsCalls += 1;
    if (error != null) throw error!;
    return collections;
  }

  @override
  Future<CollectionDetail> getCollectionDetail(
    String collectionId, {
    int limit = 25,
    int? offset,
    String? cursor,
  }) async {
    detailCalls += 1;
    if (error != null) throw error!;
    if (detailQueue.isNotEmpty) return detailQueue.removeAt(0);
    return _detail(collectionId);
  }

  @override
  Future<CollectionSummary> createCollection({
    required String name,
    String description = '',
    List<String> reelIds = const [],
  }) async {
    if (mutationError != null) throw mutationError!;
    return _summary('created');
  }

  @override
  Future<CollectionSummary> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    String? coverReelId,
  }) async {
    if (mutationError != null) throw mutationError!;
    return CollectionSummary(id: collectionId, name: name ?? 'Renamed');
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<int> addReelsToCollection({
    required String collectionId,
    required List<String> reelIds,
  }) async {
    if (mutationError != null) throw mutationError!;
    return reelIds.length;
  }

  @override
  Future<void> removeReelFromCollection({
    required String collectionId,
    required String reelId,
  }) async {
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<CollectionLink> enableCollectionLink(String collectionId) async {
    if (mutationError != null) throw mutationError!;
    return CollectionLink(
      url: 'https://reelpin.in/c/tok-$collectionId',
      token: 'tok-$collectionId',
    );
  }

  @override
  Future<void> disableCollectionLink(String collectionId) async {
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<CollectionMembers> getCollectionMembers(String collectionId) async {
    if (membersError != null) throw membersError!;
    return const CollectionMembers(ownerId: 'owner-1');
  }

  @override
  Future<void> removeCollectionMember({
    required String collectionId,
    required String memberUserId,
  }) async {
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<void> leaveCollection(String collectionId) async {
    if (mutationError != null) throw mutationError!;
  }

  @override
  Future<CollectionInvite> createCollectionInvite({
    required String collectionId,
    required String role,
  }) async {
    if (mutationError != null) throw mutationError!;
    return CollectionInvite(url: 'https://reelpin.in/c/invite/x', token: 'x', role: role);
  }

  @override
  Future<CollectionSummary> acceptCollectionInvite(String token) async {
    if (mutationError != null) throw mutationError!;
    return const CollectionSummary(id: 'joined', name: 'Joined', role: 'editor');
  }

  @override
  Future<CollectionDetail> getSharedCollection(
    String token, {
    int limit = 25,
    int? offset,
  }) async {
    if (error != null) throw error!;
    return _detail('shared');
  }
}
