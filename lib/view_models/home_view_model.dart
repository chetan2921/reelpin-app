import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/utils/error_message.dart';

class HomeViewModel extends ChangeNotifier {
  final ReelRepository _repository;
  final void Function(String reelId)? _onReelDeleted;

  HomeViewModel(this._repository, {void Function(String reelId)? onReelDeleted})
    : _onReelDeleted = onReelDeleted {
    _repository.addListener(_syncFromRepository);
  }

  List<Reel> _reels = [];
  bool _isLoading = false;
  bool _hasSettledFirstLoad = false;

  /// Which filter the in-flight load is for, and a counter so a slow load for
  /// an abandoned filter cannot overwrite a newer one.
  String? _loadingCategory;
  String? _loadingSubcategory;
  int _loadRequest = 0;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedPlatform;
  String? _selectedCategory;
  String? _selectedSubcategory;

  List<Reel> get reels => List.unmodifiable(_reels);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => _repository.hasMoreReels;
  int get totalCount => _repository.totalCount;
  String? get error => _error;
  String? get selectedPlatform => _selectedPlatform;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubcategory => _selectedSubcategory;
  bool get hasActiveFilters =>
      _selectedPlatform != null ||
      _selectedCategory != null ||
      _selectedSubcategory != null;
  List<Reel> get allReels => List.unmodifiable(_reels);

  /// Whether a load has finished at least once this session.
  ///
  /// Before that, an empty list means "we have not looked yet", not "there is
  /// nothing here" — telling the two apart is what keeps the empty state from
  /// flashing on the first frame, before the initial load has even started.
  bool get hasSettledFirstLoad => _hasSettledFirstLoad;

  bool get isEmpty => _reels.isEmpty && !_isLoading && _hasSettledFirstLoad;

  void _syncFromRepository() {
    _reels = List<Reel>.from(_repository.cachedReels);
    notifyListeners();
  }

  Future<void> loadReels({bool forceRefresh = false}) async {
    // Only a load for the *same* filter is redundant. Bailing on any in-flight
    // load meant tapping a second category while the first was still running
    // silently did nothing at all — the tap looked ignored.
    if (_isLoading &&
        _loadingCategory == _selectedCategory &&
        _loadingSubcategory == _selectedSubcategory) {
      return;
    }

    final request = ++_loadRequest;
    _isLoading = true;
    _loadingCategory = _selectedCategory;
    _loadingSubcategory = _selectedSubcategory;
    _error = null;
    notifyListeners();

    try {
      await _repository.loadInitialReels(
        forceRefresh: forceRefresh,
        platform: _selectedPlatform,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
      );
      // A newer filter has been asked for since; its result is the one to show.
      if (request != _loadRequest) return;
      _reels = List<Reel>.from(_repository.cachedReels);
    } catch (e) {
      if (request != _loadRequest) return;
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load saved reels right now.',
      );
    } finally {
      if (request == _loadRequest) {
        _isLoading = false;
        _hasSettledFirstLoad = true;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreReels() async {
    if (_isLoading || _isLoadingMore || !hasMoreReels) {
      return;
    }

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.loadMoreReels(
        platform: _selectedPlatform,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
      );
      _reels = List<Reel>.from(_repository.cachedReels);
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load more reels right now.',
      );
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Tapping the category row. The platform stays put — the row is a
  /// refinement inside the current platform, not a replacement for it.
  void filterByCategory(String? category) {
    final nextCategory = _selectedCategory == category ? null : category;
    applyFilters(platform: _selectedPlatform, category: nextCategory);
  }

  void applyFilters({String? platform, String? category, String? subcategory}) {
    _selectedPlatform = platform;
    _selectedCategory = category;
    _selectedSubcategory = subcategory;
    unawaited(loadReels(forceRefresh: true));
    notifyListeners();
  }

  void clearFilters() {
    _selectedPlatform = null;
    _selectedCategory = null;
    _selectedSubcategory = null;
    unawaited(loadReels(forceRefresh: true));
    notifyListeners();
  }

  void reset() {
    _selectedPlatform = null;
    _selectedCategory = null;
    _selectedSubcategory = null;
    _error = null;
    _isLoading = false;
    // A new user has not been looked up yet, so their library is "unknown"
    // again rather than "empty".
    _hasSettledFirstLoad = false;
    _isLoadingMore = false;
    _reels = List<Reel>.from(_repository.cachedReels);
    notifyListeners();
  }

  Future<Reel> processReel(
    String url, {
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reel = await _repository.processReel(url, onJobUpdate: onJobUpdate);
      _reels = List<Reel>.from(_repository.cachedReels);
      return reel;
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not save this reel right now.',
      );
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ProcessingJob> enqueueReelProcessing(
    String url, {
    List<String> collectionIds = const [],
  }) async {
    _error = null;
    notifyListeners();

    try {
      return await _repository.enqueueReelProcessing(
        url,
        collectionIds: collectionIds,
      );
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not start background save.',
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteReel(String reelId) async {
    await _repository.deleteReel(reelId);
    _removeReelLocally(reelId);
    _onReelDeleted?.call(reelId);
  }

  void removeReel(String reelId) {
    _removeReelLocally(reelId);
  }

  void _removeReelLocally(String reelId) {
    _reels.removeWhere((r) => r.id == reelId);
    notifyListeners();
  }

  void upsertProcessedReel(Reel reel) {
    unawaited(loadReels(forceRefresh: true));
  }

  @override
  void dispose() {
    _repository.removeListener(_syncFromRepository);
    super.dispose();
  }
}
