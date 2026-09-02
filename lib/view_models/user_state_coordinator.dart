import 'dart:async';

import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/view_models/entitlements_view_model.dart';
import 'package:reelpin/view_models/discover_view_model.dart';
import 'package:reelpin/view_models/search_view_model.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/view_models/processing_jobs_view_model.dart';

/// Owns the lifecycle of everything scoped to the signed-in user: restoring it
/// on startup and clearing it when the user changes.
class UserStateCoordinator {
  UserStateCoordinator({
    required SearchViewModel searchViewModel,
    required ReelFiltersViewModel reelFiltersViewModel,
    required MapViewModel mapViewModel,
    required HomeViewModel homeViewModel,
    required DiscoverViewModel discoverViewModel,
    required ReelRepository reelRepository,
    required EntitlementsViewModel entitlementsViewModel,
    required ProcessingJobsViewModel processingJobsViewModel,
  }) : _searchViewModel = searchViewModel,
       _reelFiltersViewModel = reelFiltersViewModel,
       _mapViewModel = mapViewModel,
       _homeViewModel = homeViewModel,
       _discoverViewModel = discoverViewModel,
       _reelRepository = reelRepository,
       _entitlementsViewModel = entitlementsViewModel,
       _processingJobsViewModel = processingJobsViewModel;

  final SearchViewModel _searchViewModel;
  final ReelFiltersViewModel _reelFiltersViewModel;
  final MapViewModel _mapViewModel;
  final HomeViewModel _homeViewModel;
  final DiscoverViewModel _discoverViewModel;
  final ReelRepository _reelRepository;
  final EntitlementsViewModel _entitlementsViewModel;
  final ProcessingJobsViewModel _processingJobsViewModel;

  Future<void>? _hydrationFuture;

  /// Restores the last saved snapshot of every tab on cold start.
  ///
  /// Runs before — and in parallel with — the network refresh. Each view model
  /// drops its cached payload the moment live data arrives, so the worst case
  /// of a slow disk read is that the snapshot is simply skipped.
  Future<void> hydrate() {
    final existing = _hydrationFuture;
    if (existing != null) return existing;

    final future = _hydrate();
    _hydrationFuture = future;
    return future;
  }

  Future<void> _hydrate() async {
    try {
      // Access state alongside the reels: the home screen gates content on it,
      // so restoring both together avoids a paywall flash on a restricted plan.
      await Future.wait<void>([
        _entitlementsViewModel.hydrateFromCache(),
        _reelRepository.hydrateCache(),
        _reelFiltersViewModel.hydrateFromCache(),
        _mapViewModel.hydrateFromCache(),
        _discoverViewModel.hydrateFromCache(),
      ]);
    } catch (e) {
      AppLogger.error('Cache hydration skipped: $e');
    }
  }

  /// Drops everything belonging to the previous user and re-arms hydration so
  /// the next sign-in can restore its own snapshot.
  void reset() {
    _hydrationFuture = null;
    _searchViewModel.clear();
    _reelFiltersViewModel.reset();
    _mapViewModel.reset();
    _homeViewModel.reset();
    _discoverViewModel.reset();
    _reelRepository.clearCache();
    _entitlementsViewModel.reset();
    _processingJobsViewModel.reset();
  }
}
