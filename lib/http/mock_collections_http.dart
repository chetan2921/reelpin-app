import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/api_exception.dart';
import 'package:reelpin/http/collections_http.dart';

/// Swaps the collections backend for [MockCollectionsHttp] so the SAVED tab can
/// be driven before the real endpoints exist. Start the app with
/// `--dart-define=MOCK_COLLECTIONS=true`; the `kDebugMode` half is a compile
/// time constant, so release builds fold this to `false` and drop the mock.
const bool useMockCollections =
    kDebugMode && bool.fromEnvironment('MOCK_COLLECTIONS');

/// In-memory [CollectionsHttp] that keeps every mutation for the life of the
/// process. Mirrors the real client's contract: the same return shapes, the
/// same [ApiException]s for missing or forbidden collections, and a short delay
/// on each call so loading and error states actually render.
class MockCollectionsHttp implements CollectionsHttp {
  MockCollectionsHttp() {
    _seed();
  }

  static const Duration _latency = Duration(milliseconds: 450);
  static const String _ownerId = 'mock-owner';
  static const String _meId = 'mock-me';

  final Map<String, CollectionSummary> _collections = {};
  final Map<String, List<Reel>> _reels = {};
  final Map<String, List<CollectionMember>> _members = {};
  final Map<String, String> _linkTokens = {};
  final Map<String, String> _inviteTokens = {};
  final Map<String, String> _inviteRoles = {};

  var _nextId = 100;

  // ─── Seed Data ───

  void _seed() {
    _add(
      const CollectionSummary(
        id: 'c-tokyo',
        name: 'Tokyo Food Crawl',
        description:
            'Ramen, standing sushi, and the yakitori alley under the tracks. '
            'Booked for March.',
        visibility: 'private',
        role: 'owner',
        memberCount: 1,
      ),
      _makeReels('tokyo', 30, 'Food', 'instagram'),
    );

    _add(
      const CollectionSummary(
        id: 'c-hikes',
        name: 'Weekend Hikes',
        description: 'Anything under three hours from the city.',
        visibility: 'link',
        role: 'owner',
        memberCount: 1,
      ),
      _makeReels('hikes', 7, 'Travel', 'youtube'),
    );
    _linkTokens['c-hikes'] = 'mock-link-hikes';

    _add(
      const CollectionSummary(
        id: 'c-apartment',
        name: 'Apartment Ideas',
        description: 'Shared board. Add anything you like for the living room.',
        visibility: 'link',
        role: 'editor',
        memberCount: 3,
      ),
      _makeReels('apartment', 12, 'Home', 'pinterest'),
    );
    _linkTokens['c-apartment'] = 'mock-link-apartment';
    _members['c-apartment'] = const [
      CollectionMember(userId: _meId, role: 'editor'),
      CollectionMember(userId: 'mock-friend-1', role: 'viewer'),
    ];

    _add(
      const CollectionSummary(
        id: 'c-empty',
        name: 'Someday',
        description: '',
        visibility: 'private',
        role: 'owner',
        memberCount: 1,
      ),
      const [],
    );
  }

  void _add(CollectionSummary collection, List<Reel> reels) {
    _collections[collection.id] = collection.copyWith(itemCount: reels.length);
    _reels[collection.id] = List<Reel>.from(reels);
    _members.putIfAbsent(collection.id, () => const []);
  }

  List<Reel> _makeReels(
    String prefix,
    int count,
    String category,
    String platform,
  ) {
    return List<Reel>.generate(count, (index) {
      final n = index + 1;
      return _makeReel(
        id: '$prefix-reel-$n',
        title: '${_titles[index % _titles.length]} #$n',
        category: category,
        platform: platform,
        daysAgo: index,
      );
    }, growable: false);
  }

  /// Built through [Reel.fromJson] rather than the constructor so the derived
  /// fields (labels, display dates, map flags) come out exactly as they would
  /// from the real API.
  Reel _makeReel({
    required String id,
    required String title,
    required String category,
    required String platform,
    required int daysAgo,
  }) {
    final savedAt = DateTime(2026, 8, 5).subtract(Duration(days: daysAgo));
    return Reel.fromJson({
      'id': id,
      'user_id': _meId,
      'url': 'https://example.com/$platform/$id',
      'source_url': 'https://example.com/$platform/$id',
      'source_platform': platform,
      // Left blank on purpose: ReelCard falls back to its category colour, so
      // the mock never depends on the network to render.
      'thumbnail_url': '',
      'title': title,
      'summary': 'Mock reel used to exercise the collections UI.',
      'caption': title,
      'transcript': '',
      'category': category,
      'sub_category': category,
      'key_facts': const <String>[],
      'locations': const <Map<String, dynamic>>[],
      'people_mentioned': const <String>[],
      'actionable_items': const <String>[],
      'created_at': savedAt.toIso8601String(),
    });
  }

  static const _titles = [
    'Standing sushi counter',
    'Late night ramen',
    'Yakitori under the tracks',
    'Coffee stand in the alley',
    'Rooftop bar with the view',
    'The bakery everyone queues for',
    'Tiny curry shop',
    'Market breakfast',
  ];

  // ─── Reads ───

  @override
  Future<List<CollectionSummary>> getCollections() async {
    await _wait();
    return _collections.values.toList(growable: false);
  }

  @override
  Future<CollectionDetail> getCollectionDetail(
    String collectionId, {
    int limit = 25,
    int? offset,
    String? cursor,
  }) async {
    await _wait();
    final collection = _require(collectionId);
    return _detail(collection, limit: limit, offset: offset ?? 0);
  }

  @override
  Future<CollectionDetail> getSharedCollection(
    String token, {
    int limit = 25,
    int? offset,
  }) async {
    await _wait();
    final id = _linkTokens.entries
        .where((entry) => entry.value == token)
        .map((entry) => entry.key)
        .firstOrNull;
    if (id == null) {
      throw ApiException('This shared collection is no longer available.', 404);
    }
    // A shared viewer is not a member: read-only, and the owner is named.
    return _detail(
      _require(id).copyWith(role: 'viewer'),
      limit: limit,
      offset: offset ?? 0,
      canEdit: false,
      ownerName: 'Mock Owner',
    );
  }

  CollectionDetail _detail(
    CollectionSummary collection, {
    required int limit,
    required int offset,
    bool? canEdit,
    String? ownerName,
  }) {
    final all = _reels[collection.id] ?? const <Reel>[];
    final start = offset.clamp(0, all.length);
    final end = (start + limit).clamp(0, all.length);
    final page = all.sublist(start, end);
    return CollectionDetail(
      collection: collection,
      reels: page,
      pagination: CollectionPagination(
        nextOffset: end < all.length ? end : null,
        hasMore: end < all.length,
        limit: limit,
        offset: start,
        totalCount: all.length,
      ),
      canEdit: canEdit ?? collection.canEdit,
      ownerName: ownerName,
    );
  }

  @override
  Future<CollectionMembers> getCollectionMembers(String collectionId) async {
    await _wait();
    _require(collectionId);
    return CollectionMembers(
      ownerId: _ownerId,
      members: _members[collectionId] ?? const [],
    );
  }

  // ─── Mutations ───

  @override
  Future<CollectionSummary> createCollection({
    required String name,
    String description = '',
    List<String> reelIds = const [],
  }) async {
    await _wait();
    final id = 'c-mock-${_nextId++}';
    final reels = reelIds
        .map(
          (reelId) => _makeReel(
            id: reelId,
            title: 'Saved reel',
            category: 'Other',
            platform: 'instagram',
            daysAgo: 0,
          ),
        )
        .toList();
    final created = CollectionSummary(
      id: id,
      name: name,
      description: description,
      itemCount: reels.length,
      memberCount: 1,
    );
    _collections[id] = created;
    _reels[id] = reels;
    _members[id] = const [];
    return created;
  }

  @override
  Future<CollectionSummary> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    String? coverReelId,
  }) async {
    await _wait();
    final updated = _requireEditable(
      collectionId,
    ).copyWith(name: name, description: description, coverReelId: coverReelId);
    _collections[collectionId] = updated;
    return updated;
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    await _wait();
    _requireOwner(collectionId);
    _collections.remove(collectionId);
    _reels.remove(collectionId);
    _members.remove(collectionId);
    _linkTokens.remove(collectionId);
  }

  @override
  Future<int> addReelsToCollection({
    required String collectionId,
    required List<String> reelIds,
  }) async {
    await _wait();
    final collection = _requireEditable(collectionId);
    final reels = _reels[collectionId]!;
    final existing = reels.map((reel) => reel.id).toSet();
    var added = 0;
    for (final reelId in reelIds) {
      if (existing.contains(reelId)) continue;
      reels.insert(
        0,
        _makeReel(
          id: reelId,
          title: 'Saved reel',
          category: 'Other',
          platform: 'instagram',
          daysAgo: 0,
        ),
      );
      added++;
    }
    _collections[collectionId] = collection.copyWith(itemCount: reels.length);
    return added;
  }

  @override
  Future<void> removeReelFromCollection({
    required String collectionId,
    required String reelId,
  }) async {
    await _wait();
    final collection = _requireEditable(collectionId);
    final reels = _reels[collectionId]!..removeWhere((r) => r.id == reelId);
    _collections[collectionId] = collection.copyWith(itemCount: reels.length);
  }

  @override
  Future<CollectionLink> enableCollectionLink(String collectionId) async {
    await _wait();
    final collection = _requireOwner(collectionId);
    final token = 'mock-link-${_nextId++}';
    _linkTokens[collectionId] = token;
    _collections[collectionId] = collection.copyWith(visibility: 'link');
    return CollectionLink(url: 'https://reelpin.in/c/$token', token: token);
  }

  @override
  Future<void> disableCollectionLink(String collectionId) async {
    await _wait();
    final collection = _requireOwner(collectionId);
    _linkTokens.remove(collectionId);
    _collections[collectionId] = collection.copyWith(visibility: 'private');
  }

  @override
  Future<CollectionInvite> createCollectionInvite({
    required String collectionId,
    required String role,
  }) async {
    await _wait();
    _requireOwner(collectionId);
    final token = 'mock-invite-${_nextId++}';
    _inviteTokens[token] = collectionId;
    _inviteRoles[token] = role;
    return CollectionInvite(
      url: 'https://reelpin.in/c/invite/$token',
      token: token,
      role: role,
      expiresAt: DateTime(2026, 9, 5).toIso8601String(),
    );
  }

  @override
  Future<CollectionSummary> acceptCollectionInvite(String token) async {
    await _wait();
    final collectionId = _inviteTokens[token];
    if (collectionId == null) {
      throw ApiException('This invite is no longer valid.', 404);
    }
    final role = _inviteRoles[token] ?? 'viewer';
    final joined = _require(collectionId).copyWith(role: role);
    _collections[collectionId] = joined;
    return joined;
  }

  @override
  Future<void> removeCollectionMember({
    required String collectionId,
    required String memberUserId,
  }) async {
    await _wait();
    final collection = _requireOwner(collectionId);
    final members = List<CollectionMember>.from(_members[collectionId] ?? [])
      ..removeWhere((member) => member.userId == memberUserId);
    _members[collectionId] = members;
    _collections[collectionId] = collection.copyWith(
      memberCount: members.length + 1,
    );
  }

  @override
  Future<void> leaveCollection(String collectionId) async {
    await _wait();
    final collection = _require(collectionId);
    if (collection.isOwner) {
      throw ApiException('Owners cannot leave their own collection.', 400);
    }
    _collections.remove(collectionId);
    _reels.remove(collectionId);
    _members.remove(collectionId);
  }

  // ─── Helpers ───

  Future<void> _wait() => Future<void>.delayed(_latency);

  CollectionSummary _require(String id) {
    final collection = _collections[id];
    if (collection == null) {
      throw ApiException('That collection no longer exists.', 404);
    }
    return collection;
  }

  CollectionSummary _requireEditable(String id) {
    final collection = _require(id);
    if (!collection.canEdit) {
      throw ApiException(
        'You do not have access to edit this collection.',
        403,
      );
    }
    return collection;
  }

  CollectionSummary _requireOwner(String id) {
    final collection = _require(id);
    if (!collection.isOwner) {
      throw ApiException('Only the owner can do that.', 403);
    }
    return collection;
  }
}
