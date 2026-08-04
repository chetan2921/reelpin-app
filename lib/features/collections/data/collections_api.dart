import 'package:reelpin/features/collections/domain/collection.dart';

abstract interface class CollectionsApi {
  Future<List<CollectionSummary>> getCollections();

  Future<CollectionDetail> getCollectionDetail(
    String collectionId, {
    int limit = 25,
    int? offset,
    String? cursor,
  });

  Future<CollectionSummary> createCollection({
    required String name,
    String description = '',
    List<String> reelIds = const [],
  });

  Future<CollectionSummary> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    String? coverReelId,
  });

  Future<void> deleteCollection(String collectionId);

  Future<int> addReelsToCollection({
    required String collectionId,
    required List<String> reelIds,
  });

  Future<void> removeReelFromCollection({
    required String collectionId,
    required String reelId,
  });

  Future<CollectionLink> enableCollectionLink(String collectionId);

  Future<void> disableCollectionLink(String collectionId);

  Future<CollectionMembers> getCollectionMembers(String collectionId);

  Future<void> removeCollectionMember({
    required String collectionId,
    required String memberUserId,
  });

  Future<void> leaveCollection(String collectionId);

  Future<CollectionInvite> createCollectionInvite({
    required String collectionId,
    required String role,
  });

  Future<CollectionSummary> acceptCollectionInvite(String token);

  Future<CollectionDetail> getSharedCollection(
    String token, {
    int limit = 25,
    int? offset,
  });
}
