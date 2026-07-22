import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/features/account/data/account_api.dart';
import 'package:reelpin/app/user_state_coordinator.dart';
import 'package:reelpin/features/reels/data/reel_repository.dart';
import 'package:reelpin/features/reels/data/reels_api.dart';
import 'package:reelpin/core/network/api_service.dart';
import 'package:reelpin/features/auth/data/auth_service.dart';
import 'package:reelpin/core/platform/notification_service.dart';
import 'package:reelpin/core/platform/push_registration_service.dart';
import 'package:reelpin/features/auth/data/profile_service.dart';
import 'package:reelpin/features/sharing/services/share_flow_analytics_service.dart';
import 'package:reelpin/features/home/presentation/category_filters_viewmodel.dart';
import 'package:reelpin/features/discover/presentation/discover_viewmodel.dart';
import 'package:reelpin/features/account/presentation/entitlements_viewmodel.dart';
import 'package:reelpin/features/folders/presentation/folders_viewmodel.dart';
import 'package:reelpin/features/home/presentation/home_viewmodel.dart';
import 'package:reelpin/features/map/presentation/map_viewmodel.dart';
import 'package:reelpin/features/map/data/map_api.dart';
import 'package:reelpin/features/folders/data/folders_api.dart';
import 'package:reelpin/features/sharing/data/sharing_api.dart';
import 'package:reelpin/features/discover/presentation/search_viewmodel.dart';
import 'package:reelpin/features/auth/presentation/session_viewmodel.dart';
import 'package:reelpin/app/theme_viewmodel.dart';

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
  return SessionViewModel(
    ref.read(authServiceProvider),
    ApiService.new,
    ApiService.new,
    unregisterPushToken: () =>
        ref.read(pushRegistrationServiceProvider).unregisterCurrentDevice(),
  );
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

final reelsApiProvider = Provider<ReelsApi>((ref) {
  return ref.read(apiServiceProvider);
});

final mapApiProvider = Provider<MapApi>((ref) {
  return ref.read(apiServiceProvider);
});

final foldersApiProvider = Provider<FoldersApi>((ref) {
  return ref.read(apiServiceProvider);
});

final accountApiProvider = Provider<AccountApi>((ref) {
  return ref.read(apiServiceProvider);
});

final sharingApiProvider = Provider<SharingApi>((ref) {
  return ref.read(apiServiceProvider);
});

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((
  ref,
) {
  return PushRegistrationService(
    notificationService: ref.read(notificationServiceProvider),
    sharingApi: ref.read(sharingApiProvider),
  );
});

final reelRepositoryProvider = ChangeNotifierProvider<ReelRepository>((ref) {
  return ReelRepository(
    ref.read(apiServiceProvider),
    ref.read(authServiceProvider),
  );
});

final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>((ref) {
  return HomeViewModel(
    ref.read(reelRepositoryProvider),
    onReelDeleted: (reelId) {
      ref.read(mapViewModelProvider).removeReel(reelId);
      ref.read(discoverViewModelProvider).removeReel(reelId);
      ref.read(searchViewModelProvider).removeReel(reelId);
    },
  );
});

final mapViewModelProvider = ChangeNotifierProvider<MapViewModel>((ref) {
  return MapViewModel(ref.read(mapApiProvider));
});

final categoryFiltersViewModelProvider =
    ChangeNotifierProvider<CategoryFiltersViewModel>((ref) {
      return CategoryFiltersViewModel(ref.read(reelRepositoryProvider));
    });

final discoverViewModelProvider = ChangeNotifierProvider<DiscoverViewModel>((
  ref,
) {
  return DiscoverViewModel(ref.read(reelRepositoryProvider));
});

final searchViewModelProvider = ChangeNotifierProvider<SearchViewModel>((ref) {
  return SearchViewModel(ref.read(reelRepositoryProvider));
});

final foldersViewModelProvider = ChangeNotifierProvider<FoldersViewModel>((
  ref,
) {
  return FoldersViewModel(ref.read(foldersApiProvider));
});

final entitlementsViewModelProvider =
    ChangeNotifierProvider<EntitlementsViewModel>((ref) {
      return EntitlementsViewModel(
        ref.read(accountApiProvider),
        ref.read(authServiceProvider),
        ref.read(reelRepositoryProvider),
        ref.read(homeViewModelProvider),
        ref.read(mapViewModelProvider),
        ref.read(categoryFiltersViewModelProvider),
        ref.read(discoverViewModelProvider),
        ref.read(searchViewModelProvider),
      );
    });

final userStateCoordinatorProvider = Provider<UserStateCoordinator>((ref) {
  return UserStateCoordinator(
    searchViewModel: ref.read(searchViewModelProvider),
    categoryFiltersViewModel: ref.read(categoryFiltersViewModelProvider),
    mapViewModel: ref.read(mapViewModelProvider),
    homeViewModel: ref.read(homeViewModelProvider),
    discoverViewModel: ref.read(discoverViewModelProvider),
    reelRepository: ref.read(reelRepositoryProvider),
    entitlementsViewModel: ref.read(entitlementsViewModelProvider),
  );
});
