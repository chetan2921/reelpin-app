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
    this._searchViewModel,
  );

  final AccountHttp _accountHttp;
  final AuthService _authService;
  final ReelRepository _repository;
  final HomeViewModel _homeViewModel;
  final MapViewModel _mapViewModel;
  final ReelFiltersViewModel _reelFiltersViewModel;
  final DiscoverViewModel _discoverViewModel;
  final SearchViewModel _searchViewModel;

  EntitlementsResponse? _response;
  bool _isLoading = false;
  String? _error;
  Future<void>? _refreshFuture;
  bool _pendingReloadContent = false;
  bool _pendingSyncBilling = false;

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

    final payload = await ContentCache.instance.read(
      ContentCacheKeys.entitlements,
    );
    if (payload == null) return;
    if (_response != null) return;

    try {
      _response = EntitlementsResponse.fromJson(payload);
      notifyListeners();
    } catch (e) {
      AppLogger.error('Cached entitlements could not be restored: $e');
      unawaited(
        ContentCache.instance.invalidate(ContentCacheKeys.entitlements),
      );
    }
  }

  /// [syncBilling] makes the backend re-read RevenueCat first; it is set
  /// only right after a purchase.
  Future<void> refresh({bool reloadContent = false, bool syncBilling = false}) {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) {
      _pendingReloadContent = _pendingReloadContent || reloadContent;
      // A refresh that started before the purchase must not swallow the
      // post-purchase sync; it runs as soon as that one ends.
      _pendingSyncBilling = _pendingSyncBilling || syncBilling;
      return activeRefresh;
    }

    final shouldReloadContent = reloadContent || _pendingReloadContent;
    final shouldSyncBilling = syncBilling || _pendingSyncBilling;
    _pendingReloadContent = false;
    _pendingSyncBilling = false;
    final future = _refresh(
      reloadContent: shouldReloadContent,
      syncBilling: shouldSyncBilling,
    );
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
        final reload = _pendingReloadContent;
        final sync = _pendingSyncBilling;
        if (reload || sync) {
          _pendingReloadContent = false;
          _pendingSyncBilling = false;
          unawaited(refresh(reloadContent: reload, syncBilling: sync));
        }
      }
    });
  }

  Future<void> _refresh({
    required bool reloadContent,
    required bool syncBilling,
  }) async {
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
      final next = await _accountHttp.getAccountEntitlements(
        userId: userId,
        sync: syncBilling,
      );
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
        _reelFiltersViewModel.reset();
        _discoverViewModel.reset();
        _searchViewModel.clear();
      }

      _response = next;
      notifyListeners();

      if (shouldResetVisibleData) {
        await _repository.clearUserCache();
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
