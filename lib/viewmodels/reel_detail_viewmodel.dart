import 'package:flutter/foundation.dart';

import '../models/reel.dart';
import '../repositories/reel_repository.dart';

/// ViewModel for the Reel Detail screen.
class ReelDetailViewModel extends ChangeNotifier {
  final ReelRepository _repository;

  ReelDetailViewModel(this._repository);

  Reel? _reel;
  bool _isLoading = false;
  String? _error;
  bool _isTranscriptExpanded = false;

  Reel? get reel => _reel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTranscriptExpanded => _isTranscriptExpanded;

  /// Load a single reel by ID.
  Future<void> loadReel(String reelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reel = await _repository.getReel(reelId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set reel directly (when navigating with data).
  void setReel(Reel reel) {
    _reel = reel;
    notifyListeners();
  }

  /// Toggle transcript expansion.
  void toggleTranscript() {
    _isTranscriptExpanded = !_isTranscriptExpanded;
    notifyListeners();
  }

  /// Delete this reel.
  Future<bool> deleteReel() async {
    if (_reel == null) return false;
    try {
      await _repository.deleteReel(_reel!.id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
