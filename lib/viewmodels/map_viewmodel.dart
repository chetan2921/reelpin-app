import 'package:flutter/foundation.dart';

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

    return List.unmodifiable(_reelsWithLocations.where(_matchesFilter));
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
}
