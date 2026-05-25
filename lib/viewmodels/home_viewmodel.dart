import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/processing_job.dart';
import '../models/reel.dart';
import '../repositories/reel_repository.dart';
import '../services/api_service.dart';

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

  List<Reel> get reels => List.unmodifiable(_reels);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => _repository.hasMoreReels;
  int get totalCount => _repository.totalCount;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubcategory => _selectedSubcategory;
  List<Reel> get allReels => List.unmodifiable(_reels);
  bool get isEmpty => _reels.isEmpty && !_isLoading;

  void _syncFromRepository() {
    _reels = List<Reel>.from(_repository.cachedReels);
    notifyListeners();
  }

  Future<void> loadReels({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.loadInitialReels(
        forceRefresh: forceRefresh,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
      );
      _reels = List<Reel>.from(_repository.cachedReels);
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load saved reels right now.',
      );
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
      await _repository.loadMoreReels(
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

  void filterByCategory(String? category) {
    final nextCategory = _selectedCategory == category ? null : category;
    applyFilters(category: nextCategory);
  }

  void applyFilters({String? category, String? subcategory}) {
    _selectedCategory = category;
    _selectedSubcategory = subcategory;
    unawaited(loadReels(forceRefresh: true));
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategory = null;
    _selectedSubcategory = null;
    unawaited(loadReels(forceRefresh: true));
    notifyListeners();
  }

  void reset() {
    _selectedCategory = null;
    _selectedSubcategory = null;
    _error = null;
    _isLoading = false;
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

  Future<ProcessingJob> enqueueReelProcessing(String url) async {
    _error = null;
    notifyListeners();

    try {
      return await _repository.enqueueReelProcessing(url);
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
