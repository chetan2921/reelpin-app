import 'package:reelpin/features/folders/domain/folder.dart';

abstract interface class FoldersApi {
  Future<List<FolderSummary>> getFolders();

  Future<FolderDetailResponse> getFolderDetail(
    String folderId, {
    int limit = 25,
    int? offset,
    String? cursor,
  });

  Future<FolderSummary> updateFolder({
    required String folderId,
    required String name,
    required String note,
  });

  Future<void> deleteFolder(String folderId);

  Future<void> addReelsToFolder({
    required String folderId,
    required List<String> reelIds,
    bool moveExisting = false,
  });

  Future<void> removeReelFromFolder({
    required String folderId,
    required String reelId,
  });
}
