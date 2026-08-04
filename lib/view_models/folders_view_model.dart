import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/http/folders_http.dart';
import 'package:reelpin/data_models/folders/folder_models.dart';

class FoldersViewModel extends ChangeNotifier {
  FoldersViewModel(this._foldersHttp);

  static const _pageSize = 25;

  final FoldersHttp _foldersHttp;

  List<FolderSummary> _folders = const [];
  final Map<String, FolderDetailResponse> _details = {};
  bool _isLoadingFolders = false;
  bool _isLoadingDetail = false;
  bool _isMutating = false;
  String? _foldersError;
  String? _detailError;
  Future<void>? _loadFoldersFuture;
  final Map<String, Future<void>> _loadDetailFutures = {};

  List<FolderSummary> get folders => List.unmodifiable(_folders);
  bool get isLoadingFolders => _isLoadingFolders;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isMutating => _isMutating;
  String? get foldersError => _foldersError;
  String? get detailError => _detailError;

  FolderDetailResponse? detailFor(String folderId) => _details[folderId];

  Future<void> loadFolders({bool forceRefresh = false}) {
    if (_loadFoldersFuture != null) return _loadFoldersFuture!;
    if (!forceRefresh && _folders.isNotEmpty) return Future<void>.value();

    final future = _loadFolders();
    _loadFoldersFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFoldersFuture, future)) {
        _loadFoldersFuture = null;
      }
    });
  }

  Future<void> _loadFolders() async {
    _isLoadingFolders = true;
    _foldersError = null;
    notifyListeners();

    try {
      _folders = await _foldersHttp.getFolders();
    } catch (e) {
      _foldersError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load folders right now.',
      );
    } finally {
      _isLoadingFolders = false;
      notifyListeners();
    }
  }

  Future<void> loadFolder(String folderId, {bool forceRefresh = false}) {
    if (_loadDetailFutures[folderId] != null) {
      return _loadDetailFutures[folderId]!;
    }
    if (!forceRefresh && _details.containsKey(folderId)) {
      return Future<void>.value();
    }

    final future = _loadFolder(folderId);
    _loadDetailFutures[folderId] = future;
    return future.whenComplete(() {
      if (identical(_loadDetailFutures[folderId], future)) {
        _loadDetailFutures.remove(folderId);
      }
    });
  }

  Future<void> _loadFolder(String folderId) async {
    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();

    try {
      final detail = await _foldersHttp.getFolderDetail(
        folderId,
        limit: _pageSize,
      );
      _details[folderId] = detail;
      _upsertFolder(detail.folder);
    } catch (e) {
      _detailError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load this folder right now.',
      );
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFolderReels(String folderId) async {
    if (_isLoadingDetail) return;
    final current = _details[folderId];
    if (current == null || !current.pagination.hasMore) return;

    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();

    try {
      final next = await _foldersHttp.getFolderDetail(
        folderId,
        limit: current.pagination.limit,
        offset: current.pagination.nextOffset,
        cursor: current.pagination.nextCursor,
      );
      _details[folderId] = current.append(next);
      _upsertFolder(next.folder);
    } catch (e) {
      _detailError = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load more reels right now.',
      );
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> updateFolder({
    required String folderId,
    required String name,
    required String note,
  }) async {
    await _mutate(() async {
      final folder = await _foldersHttp.updateFolder(
        folderId: folderId,
        name: name,
        note: note,
      );
      _upsertFolder(folder);
      final detail = _details[folderId];
      if (detail != null) {
        _details[folderId] = FolderDetailResponse(
          folder: folder,
          reels: detail.reels,
          pagination: detail.pagination,
        );
      }
    });
  }

  Future<void> deleteFolder(String folderId) async {
    await _mutate(() async {
      await _foldersHttp.deleteFolder(folderId);
      _folders = _folders.where((folder) => folder.id != folderId).toList();
      _details.remove(folderId);
    });
  }

  Future<void> addReelsToFolder({
    required String folderId,
    required List<String> reelIds,
    bool moveExisting = false,
  }) async {
    await _mutate(() async {
      await _foldersHttp.addReelsToFolder(
        folderId: folderId,
        reelIds: reelIds,
        moveExisting: moveExisting,
      );
    });
  }

  Future<void> removeReelFromFolder({
    required String folderId,
    required String reelId,
  }) async {
    await _mutate(() async {
      await _foldersHttp.removeReelFromFolder(
        folderId: folderId,
        reelId: reelId,
      );
      final detail = _details[folderId];
      if (detail == null) return;
      final reels = detail.reels
          .where((reel) => reel.id != reelId)
          .toList(growable: false);
      final folder = detail.folder.copyWith(reelCount: reels.length);
      _details[folderId] = FolderDetailResponse(
        folder: folder,
        reels: reels,
        pagination: detail.pagination,
      );
      _upsertFolder(folder);
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    _isMutating = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  void _upsertFolder(FolderSummary folder) {
    if (folder.id.isEmpty) return;
    final index = _folders.indexWhere((item) => item.id == folder.id);
    if (index == -1) {
      _folders = [..._folders, folder];
      return;
    }
    final next = [..._folders];
    next[index] = folder;
    _folders = next;
  }
}
