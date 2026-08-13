import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/http/collections_http.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/services/sharing/share_handoff_service.dart';

class CollectionsViewModel extends ChangeNotifier {
  CollectionsViewModel(this._api, {ContentCache? cache})
    : _cache = cache ?? ContentCache.instance;

  final CollectionsHttp _api;
  final ContentCache _cache;

  final List<CollectionSummary> _collections = [];
  bool _isLoadingCollections = false;
  bool _collectionsLoaded = false;
  String? _collectionsError;
  Future<void>? _loadCollectionsFuture;

  final Map<String, CollectionDetail> _details = {};
  bool _isLoadingDetail = false;
  String? _detailError;
  final Map<String, Future<void>> _loadDetailFutures = {};

  bool _isMutating = false;

  List<CollectionSummary> get collections => List.unmodifiable(_collections);
  bool get isLoadingCollections => _isLoadingCollections;
  String? get collectionsError => _collectionsError;
  bool get isLoadingDetail => _isLoadingDetail;
  String? get detailError => _detailError;
  bool get isMutating => _isMutating;

  CollectionDetail? detailFor(String id) => _details[id];

  /// Paints the last known grid immediately so opening SAVED never shows a
  /// spinner on a warm start. The network refresh still runs and overwrites
  /// this, exactly like Discover and Home.
  Future<void> hydrateFromCache() async {
    if (_collections.isNotEmpty) return;
    final payload = await _cache.read(ContentCacheKeys.collections);
    if (payload == null || _collections.isNotEmpty) return;
    try {
      final raw = payload['collections'];
      if (raw is! List) return;
      _collections
        ..clear()
        ..addAll(
          raw.whereType<Map>().map(
            (item) => CollectionSummary.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached collections could not be restored: $e');
      unawaited(_cache.invalidate(ContentCacheKeys.collections));
    }
  }

  Future<void> loadCollections({bool forceRefresh = false}) {
    if (_loadCollectionsFuture != null) return _loadCollectionsFuture!;
    if (_collectionsLoaded && !forceRefresh) return Future.value();
    final future = _loadCollections();
    _loadCollectionsFuture = future.whenComplete(() {
      _loadCollectionsFuture = null;
    });
    return _loadCollectionsFuture!;
  }

  Future<void> _loadCollections() async {
    // With cached rows on screen this stays false, so a refresh never replaces
    // a populated grid with a spinner.
    _isLoadingCollections = _collections.isEmpty;
    _collectionsError = null;
    notifyListeners();
    try {
      final result = await _api.getCollections();
      _collections
        ..clear()
        ..addAll(result);
      _collectionsLoaded = true;
      unawaited(_syncShareTargets());
      unawaited(
        _cache.write(ContentCacheKeys.collections, {
          'collections': result.map((c) => c.toJson()).toList(),
        }),
      );
    } catch (e) {
      _collectionsError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load collections right now.',
      );
    } finally {
      _isLoadingCollections = false;
      notifyListeners();
    }
  }

  Future<void> loadCollectionDetail(String id, {bool forceRefresh = false}) {
    final existing = _loadDetailFutures[id];
    if (existing != null) return existing;
    if (_details.containsKey(id) && !forceRefresh) return Future.value();
    final future = _loadCollectionDetail(id);
    _loadDetailFutures[id] = future.whenComplete(() {
      _loadDetailFutures.remove(id);
    });
    return _loadDetailFutures[id]!;
  }

  Future<void> _loadCollectionDetail(String id) async {
    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();
    try {
      _details[id] = await _api.getCollectionDetail(id);
    } catch (e) {
      _detailError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load this collection right now.',
      );
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(String id) async {
    final current = _details[id];
    if (current == null || !current.pagination.hasMore) return;
    try {
      final next = await _api.getCollectionDetail(
        id,
        offset: current.pagination.nextOffset,
        cursor: current.pagination.nextCursor,
      );
      _details[id] = current.append(next);
      notifyListeners();
    } catch (e) {
      _detailError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load more reels right now.',
      );
      notifyListeners();
    }
  }

  Future<CollectionSummary?> createCollection({
    required String name,
    String description = '',
    List<String> reelIds = const [],
  }) async {
    CollectionSummary? created;
    await _mutate(() async {
      created = await _api.createCollection(
        name: name,
        description: description,
        reelIds: reelIds,
      );
      _upsert(created!);
    });
    return created;
  }

  Future<void> updateCollection({
    required String collectionId,
    String? name,
    String? description,
  }) async {
    await _mutate(() async {
      final updated = await _api.updateCollection(
        collectionId: collectionId,
        name: name,
        description: description,
      );
      _upsert(updated);
      final detail = _details[collectionId];
      if (detail != null) {
        _details[collectionId] = detail.copyWith(collection: updated);
      }
    });
  }

  Future<void> deleteCollection(String id) async {
    await _mutate(() async {
      await _api.deleteCollection(id);
      _collections.removeWhere((c) => c.id == id);
      _details.remove(id);
    });
  }

  Future<int> addReels({
    required String collectionId,
    required List<String> reelIds,
  }) async {
    var added = 0;
    await _mutate(() async {
      added = await _api.addReelsToCollection(
        collectionId: collectionId,
        reelIds: reelIds,
      );
    });
    await loadCollectionDetail(collectionId, forceRefresh: true);
    await loadCollections(forceRefresh: true);
    return added;
  }

  Future<void> removeReel({
    required String collectionId,
    required String reelId,
  }) async {
    await _mutate(() async {
      await _api.removeReelFromCollection(
        collectionId: collectionId,
        reelId: reelId,
      );
      final detail = _details[collectionId];
      if (detail != null) {
        final reels = detail.reels
            .where((r) => r.id != reelId)
            .toList(growable: false);
        _details[collectionId] = detail.copyWith(
          reels: reels,
          collection: detail.collection.copyWith(
            itemCount: (detail.collection.itemCount - 1).clamp(0, 1 << 30),
          ),
        );
      }
    });
  }

  Future<CollectionLink?> enableLink(String id) async {
    CollectionLink? link;
    await _mutate(() async {
      link = await _api.enableCollectionLink(id);
      _setVisibility(id, 'link');
    });
    return link;
  }

  Future<void> disableLink(String id) async {
    await _mutate(() async {
      await _api.disableCollectionLink(id);
      _setVisibility(id, 'private');
    });
  }

  Future<CollectionMembers?> loadMembers(String id) async {
    try {
      return await _api.getCollectionMembers(id);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeMember({
    required String collectionId,
    required String memberUserId,
  }) async {
    await _mutate(() async {
      await _api.removeCollectionMember(
        collectionId: collectionId,
        memberUserId: memberUserId,
      );
    });
  }

  Future<CollectionInvite?> createInvite({
    required String collectionId,
    required String role,
  }) async {
    CollectionInvite? invite;
    await _mutate(() async {
      invite = await _api.createCollectionInvite(
        collectionId: collectionId,
        role: role,
      );
    });
    return invite;
  }

  Future<void> leave(String id) async {
    await _mutate(() async {
      await _api.leaveCollection(id);
      _collections.removeWhere((c) => c.id == id);
      _details.remove(id);
    });
  }

  Future<CollectionSummary?> acceptInvite(String token) async {
    CollectionSummary? joined;
    await _mutate(() async {
      joined = await _api.acceptCollectionInvite(token);
      _upsert(joined!);
    });
    return joined;
  }

  Future<void> _mutate(Future<void> Function() action) async {
    _isMutating = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isMutating = false;
      notifyListeners();
      unawaited(_syncShareTargets());
    }
  }

  /// Keeps the native share sheet's collection list current. Fire-and-forget:
  /// the picker is a convenience, and a stale list only means one fewer
  /// shortcut, never a lost reel.
  Future<void> _syncShareTargets() {
    return ShareHandoffService.instance.syncCollections(_collections);
  }

  void _upsert(CollectionSummary collection) {
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index >= 0) {
      _collections[index] = collection;
    } else {
      _collections.insert(0, collection);
    }
  }

  void _setVisibility(String id, String visibility) {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _collections[index] = _collections[index].copyWith(
        visibility: visibility,
      );
    }
    final detail = _details[id];
    if (detail != null) {
      _details[id] = detail.copyWith(
        collection: detail.collection.copyWith(visibility: visibility),
      );
    }
  }
}
