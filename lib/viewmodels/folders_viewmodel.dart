import 'package:flutter/foundation.dart';

import '../models/folder.dart';
import '../repositories/reel_repository.dart';
import '../services/api_service.dart';

class FoldersViewModel extends ChangeNotifier {
  FoldersViewModel(this._repository);

  static const _pageSize = 25;

  final ReelRepository _repository;

  List<FolderSummary> _folders = [];
  final Map<String, FolderDetailResponse> _details = {};
  bool _isLoadingFolders = false;
  bool _isLoadingDetail = false;
  bool _isMutating = false;
  String? _foldersError;
  String? _detailError;
  int _foldersRequestId = 0;
  int _detailRequestId = 0;

  List<FolderSummary> get folders => List.unmodifiable(_folders);
  bool get isLoadingFolders => _isLoadingFolders;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isMutating => _isMutating;
  String? get foldersError => _foldersError;
  String? get detailError => _detailError;

  FolderDetailResponse? detailFor(String folderId) => _details[folderId];

  void syncDiscoverFolders(List<FolderSummary> folders) {
    if (_sameFolders(_folders, folders)) {
      return;
    }
    _folders = List<FolderSummary>.from(folders);
    notifyListeners();
  }

  Future<void> loadFolders() async {
    final requestId = ++_foldersRequestId;
    _isLoadingFolders = true;
    _foldersError = null;
    notifyListeners();

    try {
      final folders = await _repository.getFolders();
      if (requestId != _foldersRequestId) return;
      _folders = folders;
    } catch (e) {
      if (requestId != _foldersRequestId) return;
      _foldersError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load folders right now.',
      );
    } finally {
      if (requestId == _foldersRequestId) {
        _isLoadingFolders = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadFolder(String folderId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _details.containsKey(folderId)) {
      return;
    }

    final requestId = ++_detailRequestId;
    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();

    try {
      final detail = await _repository.getFolder(folderId, limit: _pageSize);
      if (requestId != _detailRequestId) return;
      _details[folderId] = detail;
      _upsertFolderSummary(detail.folder);
    } catch (e) {
      if (requestId != _detailRequestId) return;
      _detailError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load the folder right now.',
      );
    } finally {
      if (requestId == _detailRequestId) {
        _isLoadingDetail = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreFolderReels(String folderId) async {
    final current = _details[folderId];
    if (current == null || _isLoadingDetail || !current.pagination.hasMore) {
      return;
    }

    final requestId = ++_detailRequestId;
    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();

    try {
      final next = await _repository.getFolder(
        folderId,
        offset: current.pagination.nextOffset,
        cursor: current.pagination.nextCursor,
        limit: _pageSize,
      );
      if (requestId != _detailRequestId) return;
      final merged = current.copyWith(
        folder: next.folder,
        reels: [...current.reels, ...next.reels],
        pagination: next.pagination,
      );
      _details[folderId] = merged;
      _upsertFolderSummary(next.folder);
    } catch (e) {
      if (requestId != _detailRequestId) return;
      _detailError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load more reels right now.',
      );
    } finally {
      if (requestId == _detailRequestId) {
        _isLoadingDetail = false;
        notifyListeners();
      }
    }
  }

  Future<FolderMutationResponse> createFolder({
    required String name,
    String? note,
    required List<String> reelIds,
    bool moveExisting = false,
  }) async {
    _isMutating = true;
    notifyListeners();

    try {
      final response = await _repository.createFolder(
        name: name,
        note: note,
        reelIds: reelIds,
        moveExisting: moveExisting,
      );
      _upsertFolderSummary(response.folder);
      _details.remove(response.folder.id);
      return response;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<FolderMutationResponse> addReelsToFolder({
    required String folderId,
    required List<String> reelIds,
    bool moveExisting = false,
  }) async {
    _isMutating = true;
    notifyListeners();

    try {
      final response = await _repository.addReelsToFolder(
        folderId: folderId,
        reelIds: reelIds,
        moveExisting: moveExisting,
      );
      _upsertFolderSummary(response.folder);
      _details.remove(folderId);
      return response;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> updateFolder({
    required String folderId,
    String? name,
    String? note,
  }) async {
    _isMutating = true;
    notifyListeners();

    try {
      final folder = await _repository.updateFolder(
        folderId,
        name: name,
        note: note,
      );
      _upsertFolderSummary(folder);
      final detail = _details[folderId];
      if (detail != null) {
        _details[folderId] = detail.copyWith(folder: folder);
      }
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> deleteFolder(String folderId) async {
    _isMutating = true;
    notifyListeners();

    try {
      await _repository.deleteFolder(folderId);
      _folders = _folders
          .where((folder) => folder.id != folderId)
          .toList(growable: false);
      _details.remove(folderId);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> removeReelFromFolder({
    required String folderId,
    required String reelId,
  }) async {
    _isMutating = true;
    notifyListeners();

    try {
      await _repository.removeReelFromFolder(
        folderId: folderId,
        reelId: reelId,
      );
      final detail = _details[folderId];
      if (detail == null) return;
      final reels = detail.reels
          .where((reel) => reel.id != reelId)
          .toList(growable: false);
      final folder = detail.folder.copyWith(
        reelCount: detail.folder.reelCount > 0
            ? detail.folder.reelCount - 1
            : 0,
      );
      _details[folderId] = detail.copyWith(folder: folder, reels: reels);
      _upsertFolderSummary(folder);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  void removeReel(String reelId) {
    var changed = false;
    final nextDetails = Map<String, FolderDetailResponse>.from(_details);
    for (final entry in _details.entries) {
      final reels = entry.value.reels
          .where((reel) => reel.id != reelId)
          .toList(growable: false);
      if (reels.length == entry.value.reels.length) continue;

      final folder = entry.value.folder.copyWith(
        reelCount: entry.value.folder.reelCount > 0
            ? entry.value.folder.reelCount - 1
            : 0,
      );
      nextDetails[entry.key] = entry.value.copyWith(
        folder: folder,
        reels: reels,
      );
      _upsertFolderSummary(folder, notify: false);
      changed = true;
    }

    if (changed) {
      _details
        ..clear()
        ..addAll(nextDetails);
      notifyListeners();
    }
  }

  void reset() {
    _foldersRequestId += 1;
    _detailRequestId += 1;
    _folders = [];
    _details.clear();
    _isLoadingFolders = false;
    _isLoadingDetail = false;
    _isMutating = false;
    _foldersError = null;
    _detailError = null;
    notifyListeners();
  }

  void _upsertFolderSummary(FolderSummary folder, {bool notify = true}) {
    final index = _folders.indexWhere((item) => item.id == folder.id);
    if (index == -1) {
      _folders = [folder, ..._folders];
    } else {
      final next = List<FolderSummary>.from(_folders);
      next[index] = folder;
      _folders = next;
    }
    if (notify) {
      notifyListeners();
    }
  }

  bool _sameFolders(List<FolderSummary> a, List<FolderSummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.name != right.name ||
          left.note != right.note ||
          left.reelCount != right.reelCount ||
          left.updatedAt != right.updatedAt) {
        return false;
      }
    }
    return true;
  }
}
