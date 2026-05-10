import 'package:flutter/foundation.dart';

import '../models/processing_job.dart';
import '../models/reel.dart';
import '../repositories/reel_repository.dart';

/// ViewModel for the Home screen reel list.
class HomeViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  HomeViewModel(this._repository) {
    _repository.addListener(_syncFromRepository);
  }

  List<Reel> _reels = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedCategory;
  String? _selectedSubcategory;

  List<Reel> get reels {
    if (_selectedCategory == null && _selectedSubcategory == null) {
      return List.unmodifiable(_reels);
    }

    return List.unmodifiable(_reels.where(_matchesFilters));
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => _repository.hasMoreReels;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubcategory => _selectedSubcategory;
  List<Reel> get allReels => List.unmodifiable(_reels);
  bool get isEmpty => _reels.isEmpty && !_isLoading;
  int get totalPinnedLocations =>
      _reels.fold(0, (sum, reel) => sum + reel.mappableLocations.length);

  bool _matchesFilters(Reel reel) {
    if (_selectedCategory != null &&
        _normalize(reel.category) != _normalize(_selectedCategory!)) {
      return false;
    }

    if (_selectedSubcategory != null &&
        _normalize(reel.subCategory) != _normalize(_selectedSubcategory!)) {
      return false;
    }

    return true;
  }

  String _normalize(String value) => value.trim().toLowerCase();

  void _sortAndStore(List<Reel> reels) {
    reels.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      try {
        return DateTime.parse(
          b.createdAt!,
        ).compareTo(DateTime.parse(a.createdAt!));
      } catch (_) {
        return 0;
      }
    });

    _reels = reels;
  }

  void _syncFromRepository() {
    _sortAndStore(List<Reel>.from(_repository.cachedReels));
    notifyListeners();
  }

  /// Load all reels from the backend.
  Future<void> loadReels({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.loadInitialReels(forceRefresh: forceRefresh);
      _sortAndStore(List<Reel>.from(_repository.cachedReels));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
      await _repository.loadMoreReels();
      _sortAndStore(List<Reel>.from(_repository.cachedReels));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Filter by category. Pass null to clear filter.
  void filterByCategory(String? category) {
    _selectedCategory = _selectedCategory == category ? null : category;
    _selectedSubcategory = null;
    notifyListeners();
  }

  void applyFilters({String? category, String? subcategory}) {
    _selectedCategory = category;
    _selectedSubcategory = subcategory;
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategory = null;
    _selectedSubcategory = null;
    notifyListeners();
  }

  void reset() {
    _selectedCategory = null;
    _selectedSubcategory = null;
    _error = null;
    _isLoading = false;
    _isLoadingMore = false;
    _sortAndStore(List<Reel>.from(_repository.cachedReels));
    notifyListeners();
  }

  /// Process a new reel (from shared URL) and trigger loading state.
  Future<Reel> processReel(
    String url, {
    void Function(ProcessingJob job)? onJobUpdate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reel = await _repository.processReel(url, onJobUpdate: onJobUpdate);
      final next = [
        reel,
        ..._reels.where((existing) => existing.id != reel.id),
      ];
      _sortAndStore(next);
      return reel;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ProcessingJob> enqueueReelProcessing(String url) async {
    _error = null;
    notifyListeners();

    try {
      return await _repository.enqueueReelProcessing(url);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a reel.
  Future<void> deleteReel(String reelId) async {
    await _repository.deleteReel(reelId);
    _removeReelLocally(reelId);
  }

  void removeReel(String reelId) {
    _removeReelLocally(reelId);
  }

  void _removeReelLocally(String reelId) {
    _reels.removeWhere((r) => r.id == reelId);
    notifyListeners();
  }

  void upsertProcessedReel(Reel reel) {
    final next = [reel, ..._reels.where((existing) => existing.id != reel.id)];
    _sortAndStore(next);
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(_syncFromRepository);
    super.dispose();
  }
}
