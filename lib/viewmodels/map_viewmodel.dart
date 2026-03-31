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

  List<Reel> get reelsWithLocations => _selectedCategory == null
      ? List.unmodifiable(_reelsWithLocations)
      : List.unmodifiable(
          _reelsWithLocations.where((r) => r.category == _selectedCategory),
        );
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  Reel? get selectedReel => _selectedReel;

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
  void selectReel(Reel? reel) {
    _selectedReel = reel;
    notifyListeners();
  }
}
