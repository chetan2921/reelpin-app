import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/reel.dart';
import '../repositories/reel_repository.dart';

/// ViewModel for the Map screen.
class MapViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  MapViewModel(this._repository);

  List<Reel> _reelsWithLocations = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedCategory;
  Reel? _selectedReel;
  Location? _selectedLocation;

  List<Reel> get reelsWithLocations {
    if (_selectedCategory == null) {
      return List.unmodifiable(_reelsWithLocations);
    }

    final selected = _selectedCategory!;
    return List.unmodifiable(
      _reelsWithLocations.where((r) => _matchesFilter(r, selected)),
    );
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  Reel? get selectedReel => _selectedReel;
  Location? get selectedLocation => _selectedLocation;
  int get totalPinnedLocations => _reelsWithLocations.fold(
    0,
    (sum, reel) => sum + reel.mappableLocations.length,
  );

  /// Load reels that have map-pinnable locations.
  Future<void> loadMapReels({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reelsWithLocations = await _repository.getReelsWithLocations(
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
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

  void upsertProcessedReel(Reel reel) {
    if (!reel.hasMapLocations) return;

    _reelsWithLocations = [
      reel,
      ..._reelsWithLocations.where((existing) => existing.id != reel.id),
    ];
    notifyListeners();
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
}
