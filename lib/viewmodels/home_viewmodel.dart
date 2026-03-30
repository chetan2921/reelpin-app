import 'package:flutter/foundation.dart';

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

  List<Reel> get reels => _selectedCategory == null
      ? List.unmodifiable(_reels)
      : List.unmodifiable(_reels.where((r) => r.category == _selectedCategory));
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get isEmpty => _reels.isEmpty && !_isLoading;

  /// Load all reels from the backend.
  Future<void> loadReels({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reels = await _repository.getReels(forceRefresh: forceRefresh);
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
  Future<Reel> processReel(String url) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reel = await _repository.processReel(url);
      // Ensure the new reel goes straight to the top of the UI
      _reels.insert(0, reel);
      return reel;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a reel.
  Future<void> deleteReel(String reelId) async {
    await _repository.deleteReel(reelId);
    _reels.removeWhere((r) => r.id == reelId);
    notifyListeners();
  }
}
