import 'package:flutter/foundation.dart';

import '../models/reel.dart';
import '../repositories/reel_repository.dart';

/// ViewModel for the Map screen.
class MapViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  MapViewModel(this._repository) {
    _repository.addListener(_syncFromRepository);
  }

  List<Reel> _reelsWithLocations = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedCategory;
  Reel? _selectedReel;
  Location? _selectedLocation;

  List<Reel> get reelsWithLocations {
    if (_selectedCategory == null) {
      return List.unmodifiable(_reelsWithLocations);
    }

    return List.unmodifiable(_reelsWithLocations.where(_matchesFilter));
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => _repository.hasMoreReels;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  Reel? get selectedReel => _selectedReel;
  Location? get selectedLocation => _selectedLocation;
  int get totalPinnedLocations => _reelsWithLocations.fold(
    0,
    (sum, reel) => sum + reel.mappableLocations.length,
  );

  void _syncFromRepository() {
    _reelsWithLocations = _repository.cachedReels
        .where((reel) => reel.hasMapLocations)
        .toList(growable: false);

    if (_selectedReel != null &&
        _reelsWithLocations.every((reel) => reel.id != _selectedReel!.id)) {
      _selectedReel = null;
      _selectedLocation = null;
    }

    notifyListeners();
  }

  /// Load reels that have map-pinnable locations.
  Future<void> loadMapReels({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.loadInitialReels(forceRefresh: forceRefresh);
      while (_repository.hasMoreReels) {
        await _repository.loadMoreReels();
      }
      _reelsWithLocations = _repository.cachedReels
          .where((reel) => reel.hasMapLocations)
          .toList(growable: false);
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
      _reelsWithLocations = _repository.cachedReels
          .where((reel) => reel.hasMapLocations)
          .toList(growable: false);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Filter map pins by category.
  void filterByCategory(String? category) {
    _selectedCategory = _selectedCategory == category ? null : category;
    notifyListeners();
  }

  /// Select a reel (when tapping a map pin).
  void selectReel(Reel? reel, {Location? location}) {
    _selectedReel = reel;
    _selectedLocation = location;
    notifyListeners();
  }

  void reset() {
    _reelsWithLocations = const [];
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    _selectedCategory = null;
    _selectedReel = null;
    _selectedLocation = null;
    notifyListeners();
  }

  void upsertProcessedReel(Reel reel) {
    if (!reel.hasMapLocations) return;

    _reelsWithLocations = [
      reel,
      ..._reelsWithLocations.where((existing) => existing.id != reel.id),
    ];
    notifyListeners();
  }

  void removeReel(String reelId) {
    final hadSelection = _selectedReel?.id == reelId;
    _reelsWithLocations = _reelsWithLocations
        .where((reel) => reel.id != reelId)
        .toList(growable: false);
    if (hadSelection) {
      _selectedReel = null;
      _selectedLocation = null;
    }
    notifyListeners();
  }

  bool _matchesFilter(Reel reel) =>
      _normalize(reel.category) == _normalize(_selectedCategory!);

  String _normalize(String value) => value.trim().toLowerCase();

  @override
  void dispose() {
    _repository.removeListener(_syncFromRepository);
    super.dispose();
  }
}
