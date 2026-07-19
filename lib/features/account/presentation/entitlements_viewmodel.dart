import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/features/account/data/account_api.dart';
import 'package:reelpin/features/account/domain/user_entitlement.dart';
import 'package:reelpin/features/reels/data/reel_repository.dart';
import 'package:reelpin/core/network/error_message.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/features/home/presentation/category_filters_viewmodel.dart';
import 'package:reelpin/features/discover/presentation/discover_viewmodel.dart';
import 'package:reelpin/features/home/presentation/home_viewmodel.dart';
import 'package:reelpin/features/map/presentation/map_viewmodel.dart';
import 'package:reelpin/features/discover/presentation/search_viewmodel.dart';

class EntitlementsViewModel extends ChangeNotifier {
  EntitlementsViewModel(
    this._accountApi,
    this._authService,
    this._repository,
    this._homeViewModel,
    this._mapViewModel,
    this._categoryFiltersViewModel,
    this._discoverViewModel,
    this._searchViewModel,
  );

  final AccountApi _accountApi;
  final AuthService _authService;
  final ReelRepository _repository;
  final HomeViewModel _homeViewModel;
  final MapViewModel _mapViewModel;
  final CategoryFiltersViewModel _categoryFiltersViewModel;
  final DiscoverViewModel _discoverViewModel;
  final SearchViewModel _searchViewModel;

  EntitlementsResponse? _response;
  bool _isLoading = false;
  String? _error;
  Future<void>? _refreshFuture;
  bool _pendingReloadContent = false;

  EntitlementsResponse? get response => _response;
  UserEntitlement? get entitlement => _response?.currentEntitlement;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasEntitlement => _response != null;

  Future<void> refresh({bool reloadContent = false}) {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) {
      _pendingReloadContent = _pendingReloadContent || reloadContent;
      return activeRefresh;
    }

    final shouldReloadContent = reloadContent || _pendingReloadContent;
    _pendingReloadContent = false;
    final future = _refresh(reloadContent: shouldReloadContent);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
        if (_pendingReloadContent) {
          _pendingReloadContent = false;
          unawaited(refresh(reloadContent: true));
        }
      }
    });
  }

  Future<void> _refresh({required bool reloadContent}) async {
    final userId = _authService.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      reset();
      return;
    }

    final previous = _response;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final next = await _accountApi.getAccountEntitlements(userId: userId);
      final isDifferentUser =
          previous != null &&
          previous.currentEntitlement.userId != next.currentEntitlement.userId;
      final shouldResetVisibleData =
          previous != null &&
          previous.currentEntitlement.userId ==
              next.currentEntitlement.userId &&
          previous.contentAccessSignature() != next.contentAccessSignature();

      if (isDifferentUser) {
        await _repository.clearUserCache();
        _homeViewModel.reset();
        _mapViewModel.reset();
        _categoryFiltersViewModel.reset();
        _discoverViewModel.reset();
        _searchViewModel.clear();
      }

      _response = next;
      notifyListeners();

      if (shouldResetVisibleData) {
        await _repository.clearUserCache();
        _homeViewModel.reset();
        _mapViewModel.reset();
        _categoryFiltersViewModel.reset();
        _discoverViewModel.reset();
        _searchViewModel.clear();
      }

      if (reloadContent ||
          previous == null ||
          isDifferentUser ||
          shouldResetVisibleData) {
        if (!next.currentEntitlement.restricted) {
          await Future.wait([
            _homeViewModel.loadReels(forceRefresh: true),
            _mapViewModel.loadMapReels(forceRefresh: true),
            _categoryFiltersViewModel.loadCategoryFilters(forceRefresh: true),
            _discoverViewModel.loadDiscover(forceRefresh: true),
          ]);
        }
      }
    } catch (e) {
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load account access right now.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _response = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
