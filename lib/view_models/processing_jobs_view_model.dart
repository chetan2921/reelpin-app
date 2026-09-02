import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/utils/app_logger.dart';

/// The shares the backend is still working on, so the grid can hold a
/// placeholder card for each one instead of looking like nothing happened.
///
/// Jobs come from the server rather than local bookkeeping, which is what makes
/// a share queued by the native extension — with the app closed — show up on the
/// next launch.
class ProcessingJobsViewModel extends ChangeNotifier {
  ProcessingJobsViewModel(this._repository, {this.onJobsFinished});

  final ReelRepository _repository;

  /// Puts the finished reels into the grid, and is handed whatever the backend
  /// attached to the completed jobs. Awaited, so each placeholder holds its
  /// place until the card that replaces it is really there. The list is empty
  /// when a job finished without a reel payload, which is the caller's cue to
  /// fall back to a reload. Never fired for a failure.
  final Future<void> Function(List<Reel> readyReels)? onJobsFinished;

  /// Floor and ceiling for the server's `recommended_poll_after_seconds`. The
  /// floor keeps a chatty job from hammering the API; the ceiling keeps the
  /// card from sitting still long enough to look frozen.
  static const _minPollInterval = Duration(seconds: 3);
  static const _maxPollInterval = Duration(seconds: 15);

  final List<ProcessingJob> _jobs = [];
  final Map<String, List<String>> _collectionIdsByJob = {};

  /// Jobs the backend has finished, whose cards are still on screen while the
  /// reel that replaces them is fetched. Without this the card vanishes on the
  /// poll that reports success and leaves a hole until the reload lands.
  final Set<String> _settlingIds = {};
  Timer? _timer;
  bool _isForeground = true;
  bool _isFetching = false;

  List<ProcessingJob> get jobs => List.unmodifiable(_jobs);
  bool get hasJobs => _jobs.isNotEmpty;

  /// True once the backend is done with [jobId] and only the swap is pending.
  /// The card fills to the brim on this rather than stopping short.
  bool isSettling(String jobId) => _settlingIds.contains(jobId);

  /// The jobs queued into one collection, including shares this install never
  /// saw — the backend reports each job's targets, so a job recovered after a
  /// cold start lands in the right collection too.
  List<ProcessingJob> jobsForCollection(String collectionId) {
    return _jobs
        .where((job) {
          if (job.collectionIds.contains(collectionId)) return true;
          // Falls back to what this install passed at enqueue, which is all an API
          // predating `collection_ids` on the response can offer.
          return _collectionIdsByJob[job.id]?.contains(collectionId) ?? false;
        })
        .toList(growable: false);
  }

  /// Adds the job an enqueue just returned, so the card appears on the same
  /// frame as the share instead of waiting for a poll.
  void trackEnqueued(
    ProcessingJob job, {
    List<String> collectionIds = const [],
  }) {
    if (job.id.trim().isEmpty) return;
    // Re-sharing something already saved comes back complete off the server's
    // cache. There is nothing to wait for, so there is no card to show.
    if (job.terminal || job.isCompleted) return;

    if (collectionIds.isNotEmpty) {
      _collectionIdsByJob[job.id] = List<String>.from(collectionIds);
    }
    final index = _jobs.indexWhere((existing) => existing.id == job.id);
    if (index >= 0) {
      _jobs[index] = job;
    } else {
      _jobs.insert(0, job);
    }
    notifyListeners();
    _syncTimer();
  }

  /// Replaces the list with whatever the backend still has in flight.
  Future<void> refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final latest = await _repository.listProcessingJobs();
      await _applyServerJobs(latest);
    } catch (e) {
      // A failed poll is not worth surfacing: the cards already on screen stay,
      // and the next poll or refresh corrects them.
      AppLogger.error('Processing job refresh skipped: $e');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _applyServerJobs(List<ProcessingJob> latest) async {
    final active = latest
        .where((job) => !job.terminal && !job.isCompleted)
        .toList(growable: false);
    final activeIds = active.map((job) => job.id).toSet();
    final byId = {for (final job in latest) job.id: job};

    // A card that is no longer active ended one way or the other. A job that
    // aged out of the window counts as a success — that is the common ending,
    // and holding its card briefly beats dropping a reel that did arrive.
    final justFinished = <String>{};
    final failed = <String>{};
    for (final job in _jobs) {
      if (activeIds.contains(job.id) || _settlingIds.contains(job.id)) continue;
      final finished = byId[job.id];
      if (finished == null || finished.isCompleted) {
        justFinished.add(job.id);
      } else {
        failed.add(job.id);
      }
    }

    // Marked before the sweep below, or the sweep would drop the very cards
    // that are meant to hold their place.
    _settlingIds.addAll(justFinished);

    // Failures leave now, quietly. Everything else stays: the active jobs with
    // their newest progress, the finished ones brimming until they are swapped.
    _jobs.removeWhere(
      (job) => failed.contains(job.id) || !_isStillShown(job.id, activeIds),
    );
    for (var i = 0; i < _jobs.length; i++) {
      final fresh = byId[_jobs[i].id];
      if (fresh != null) _jobs[i] = fresh;
    }
    for (final job in active) {
      if (!_jobs.any((existing) => existing.id == job.id)) _jobs.insert(0, job);
    }
    for (final jobId in failed) {
      _collectionIdsByJob.remove(jobId);
    }

    notifyListeners();
    _syncTimer();

    if (justFinished.isEmpty) return;
    // The completed job carries the whole reel — thumbnail and all — so the
    // swap needs no second request and cannot race a refresh that started
    // before the reel existed.
    final readyReels = <Reel>[
      for (final jobId in justFinished)
        if (byId[jobId]?.reel != null) byId[jobId]!.reel!,
    ];
    try {
      await onJobsFinished?.call(readyReels);
    } finally {
      // Only now is there a real card to take its place.
      _jobs.removeWhere((job) => justFinished.contains(job.id));
      _settlingIds.removeAll(justFinished);
      for (final jobId in justFinished) {
        _collectionIdsByJob.remove(jobId);
      }
      notifyListeners();
      _syncTimer();
    }
  }

  bool _isStillShown(String jobId, Set<String> activeIds) {
    return activeIds.contains(jobId) || _settlingIds.contains(jobId);
  }

  /// Polling only earns its keep while there is a card on screen to update, so
  /// it starts and stops with the list and pauses with the app.
  void _syncTimer() {
    final shouldPoll =
        _isForeground && _jobs.any((job) => !_settlingIds.contains(job.id));
    if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    final interval = _pollInterval();
    if (_timer != null && _timer!.isActive && _currentInterval == interval) {
      return;
    }
    _timer?.cancel();
    _currentInterval = interval;
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  Duration? _currentInterval;

  Duration _pollInterval() {
    var seconds = _minPollInterval.inSeconds;
    for (final job in _jobs) {
      final recommended = job.recommendedPollAfterSeconds;
      if (recommended != null && recommended > seconds) seconds = recommended;
    }
    if (seconds > _maxPollInterval.inSeconds) {
      seconds = _maxPollInterval.inSeconds;
    }
    return Duration(seconds: seconds);
  }

  void setForeground(bool isForeground) {
    if (_isForeground == isForeground) return;
    _isForeground = isForeground;
    _syncTimer();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentInterval = null;
    _jobs.clear();
    _settlingIds.clear();
    _collectionIdsByJob.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
