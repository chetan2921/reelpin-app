import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reel_repository.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/share_flow_analytics_service.dart';
import '../viewmodels/category_filters_viewmodel.dart';
import '../viewmodels/entitlements_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';

final themeViewModelProvider = ChangeNotifierProvider<ThemeViewModel>((ref) {
  return ThemeViewModel()..loadPreference();
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(profileServiceProvider));
});

final sessionViewModelProvider = ChangeNotifierProvider<SessionViewModel>((
  ref,
) {
  return SessionViewModel(ref.read(authServiceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final shareFlowAnalyticsServiceProvider = Provider<ShareFlowAnalyticsService>((
  ref,
) {
  return ShareFlowAnalyticsService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final reelRepositoryProvider = ChangeNotifierProvider<ReelRepository>((ref) {
  return ReelRepository(
    ref.read(apiServiceProvider),
    ref.read(authServiceProvider),
  );
});

final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>((ref) {
  return HomeViewModel(ref.read(reelRepositoryProvider));
});

final mapViewModelProvider = ChangeNotifierProvider<MapViewModel>((ref) {
  return MapViewModel(ref.read(reelRepositoryProvider));
});

final categoryFiltersViewModelProvider =
    ChangeNotifierProvider<CategoryFiltersViewModel>((ref) {
      return CategoryFiltersViewModel(ref.read(reelRepositoryProvider));
    });

final searchViewModelProvider = ChangeNotifierProvider<SearchViewModel>((ref) {
  return SearchViewModel(ref.read(reelRepositoryProvider));
});

final entitlementsViewModelProvider =
    ChangeNotifierProvider<EntitlementsViewModel>((ref) {
      return EntitlementsViewModel(
        ref.read(apiServiceProvider),
        ref.read(authServiceProvider),
        ref.read(reelRepositoryProvider),
        ref.read(homeViewModelProvider),
        ref.read(mapViewModelProvider),
        ref.read(categoryFiltersViewModelProvider),
        ref.read(searchViewModelProvider),
      );
    });
