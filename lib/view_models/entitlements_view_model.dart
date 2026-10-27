import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/http/account_http.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:reelpin/view_models/discover_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/view_models/search_view_model.dart';

class EntitlementsViewModel extends ChangeNotifier {
  EntitlementsViewModel(
    this._accountHttp,
    this._authService,
    this._repository,
    this._homeViewModel,
    this._mapViewModel,
    this._reelFiltersViewModel,
    this._discoverViewModel,
    this._searchViewModel, {
    ContentCache? cache,
  }) : _cache = cache ?? ContentCache.instance;

  final AccountHttp _accountHttp;
  final ContentCache _cache;
  final AuthService _authService;
  final ReelRepository _repository;
  final HomeViewModel _homeViewModel;
  final MapViewModel _mapViewModel;
  final ReelFiltersViewModel _reelFiltersViewModel;
  final DiscoverViewModel _discoverViewModel;
  final SearchViewModel _searchViewModel;

  int _userGeneration = 0;
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

  /// Restores the last known access state so cached content can render without
  /// waiting on the entitlements call. Always re-checked against the server on
  /// the refresh that follows, and the backend stays the authority regardless.
  Future<void> hydrateFromCache() async {
    if (_response != null) return;

    final generation = _userGeneration;
    final payload = await _cache.read(ContentCacheKeys.entitlements);
    if (generation != _userGeneration || payload == null) return;
    if (_response != null) return;

    try {
      _response = EntitlementsResponse.fromJson(payload);
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached entitlements could not be restored: $e');
      unawaited(_cache.invalidate(ContentCacheKeys.entitlements));
    }
  }

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
    final generation = _userGeneration;
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
      final next = await _accountHttp.getAccountEntitlements(userId: userId);
      if (generation != _userGeneration) return;
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
        if (generation != _userGeneration) return;
        _homeViewModel.reset();
        _mapViewModel.reset();
        _reelFiltersViewModel.reset();
        _discoverViewModel.reset();
        _searchViewModel.clear();
      }

      _response = next;
      notifyListeners();

      if (shouldResetVisibleData) {
        await _repository.clearUserCache();
        if (generation != _userGeneration) return;
        _homeViewModel.reset();
        _mapViewModel.reset();
        _reelFiltersViewModel.reset();
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
            _reelFiltersViewModel.loadFilters(forceRefresh: true),
            _discoverViewModel.loadDiscover(forceRefresh: true),
          ]);
        }
      }
    } catch (e) {
      if (generation != _userGeneration) return;
      _error = userFacingErrorMessage(
        e,
        fallbackMessage: 'Could not load account access right now.',
      );
    } finally {
      if (generation == _userGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _userGeneration += 1;
    _refreshFuture = null;
    _pendingReloadContent = false;
    _response = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
