import 'package:reelpin/features/account/presentation/entitlements_viewmodel.dart';
import 'package:reelpin/features/discover/presentation/discover_viewmodel.dart';
import 'package:reelpin/features/discover/presentation/search_viewmodel.dart';
import 'package:reelpin/features/reels/data/reel_repository.dart';
import 'package:reelpin/features/home/presentation/category_filters_viewmodel.dart';
import 'package:reelpin/features/home/presentation/home_viewmodel.dart';
import 'package:reelpin/features/map/presentation/map_viewmodel.dart';

class UserStateCoordinator {
  const UserStateCoordinator({
    required SearchViewModel searchViewModel,
    required CategoryFiltersViewModel categoryFiltersViewModel,
    required MapViewModel mapViewModel,
    required HomeViewModel homeViewModel,
    required DiscoverViewModel discoverViewModel,
    required ReelRepository reelRepository,
    required EntitlementsViewModel entitlementsViewModel,
  }) : _searchViewModel = searchViewModel,
       _categoryFiltersViewModel = categoryFiltersViewModel,
       _mapViewModel = mapViewModel,
       _homeViewModel = homeViewModel,
       _discoverViewModel = discoverViewModel,
       _reelRepository = reelRepository,
       _entitlementsViewModel = entitlementsViewModel;

  final SearchViewModel _searchViewModel;
  final CategoryFiltersViewModel _categoryFiltersViewModel;
  final MapViewModel _mapViewModel;
  final HomeViewModel _homeViewModel;
  final DiscoverViewModel _discoverViewModel;
  final ReelRepository _reelRepository;
  final EntitlementsViewModel _entitlementsViewModel;

  void reset() {
    _searchViewModel.clear();
    _categoryFiltersViewModel.reset();
    _mapViewModel.reset();
    _homeViewModel.reset();
    _discoverViewModel.reset();
    _reelRepository.clearCache();
    _entitlementsViewModel.reset();
  }
}
