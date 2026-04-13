import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

import '../models/processing_job.dart';
import '../models/reel.dart';
import '../repositories/reel_repository.dart';

/// ViewModel for the Home screen reel list.
class HomeViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  HomeViewModel(this._repository);

  List<Reel> _reels = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedCategory;

  List<Reel> get reels {
    if (_selectedCategory == null) {
      return List.unmodifiable(_reels);
    }

    final selected = _selectedCategory!;
    return List.unmodifiable(_reels.where((r) => _matchesFilter(r, selected)));
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get isEmpty => _reels.isEmpty && !_isLoading;
  int get totalPinnedLocations =>
      _reels.fold(0, (sum, reel) => sum + reel.mappableLocations.length);

  /// Get a strictly unique list of categories present in the current loaded reels.
  List<String> get availableCategories {
    final cats = <String>{
      ..._reels.map((e) => e.category),
      ..._reels.map((e) => e.subCategory),
    }.toList();
    cats.sort();
    return cats;
  }

  bool _matchesFilter(Reel reel, String selected) {
    final grouped = ApiConfig.categoryGroups[selected];
    if (grouped != null) {
      return _matchesCategoryOrSubCategory(reel, selected) ||
          grouped.any((c) => _matchesCategoryOrSubCategory(reel, c));
    }
    return _matchesCategoryOrSubCategory(reel, selected);
  }

  bool _matchesCategoryOrSubCategory(Reel reel, String value) {
    final normalized = _normalize(value);
    return _normalize(reel.category) == normalized ||
        _normalize(reel.subCategory) == normalized;
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

  /// Load all reels from the backend.
  Future<void> loadReels({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedReels = List<Reel>.from(
        await _repository.getReels(forceRefresh: forceRefresh),
      );
      _sortAndStore(fetchedReels);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filter by category. Pass null to clear filter.
  void filterByCategory(String? category) {
    _selectedCategory = _selectedCategory == category ? null : category;
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
    _reels.removeWhere((r) => r.id == reelId);
    notifyListeners();
  }

  void upsertProcessedReel(Reel reel) {
    final next = [reel, ..._reels.where((existing) => existing.id != reel.id)];
    _sortAndStore(next);
    notifyListeners();
  }
}
