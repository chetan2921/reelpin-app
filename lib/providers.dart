import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/http/account_http.dart';
import 'package:reelpin/view_models/user_state_coordinator.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/http/reels_http.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/notifications/notification_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/sharing/push_registration_service.dart';
import 'package:reelpin/services/sharing/share_flow_analytics_service.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:reelpin/view_models/discover_view_model.dart';
import 'package:reelpin/view_models/entitlements_view_model.dart';
import 'package:reelpin/view_models/folders_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/view_models/processing_jobs_view_model.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/http/map_http.dart';
import 'package:reelpin/http/folders_http.dart';
import 'package:reelpin/http/sharing_http.dart';
import 'package:reelpin/view_models/search_view_model.dart';
import 'package:reelpin/view_models/session_view_model.dart';
import 'package:reelpin/view_models/theme_view_model.dart';
import 'package:reelpin/http/collections_http.dart';
import 'package:reelpin/http/mock_collections_http.dart';
import 'package:reelpin/components/collections/collection_tile_renderer.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

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
    ApiClient.new,
    ApiClient.new,
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

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final reelsHttpProvider = Provider<ReelsHttp>((ref) {
  return ref.read(apiClientProvider);
});

final mapHttpProvider = Provider<MapHttp>((ref) {
  return ref.read(apiClientProvider);
});

final foldersHttpProvider = Provider<FoldersHttp>((ref) {
  return ref.read(apiClientProvider);
});

final collectionsHttpProvider = Provider<CollectionsHttp>((ref) {
  // Debug-only: --dart-define=MOCK_COLLECTIONS=true swaps in in-memory data so
  // the SAVED tab works before the backend ships the endpoints.
  if (useMockCollections) return MockCollectionsHttp();
  return ref.read(apiClientProvider);
});

final collectionsViewModelProvider =
    ChangeNotifierProvider<CollectionsViewModel>((ref) {
      return CollectionsViewModel(
        ref.read(collectionsHttpProvider),
        renderShareTiles: CollectionTileRenderer.writeTiles,
      );
    });

final accountHttpProvider = Provider<AccountHttp>((ref) {
  return ref.read(apiClientProvider);
});

final sharingHttpProvider = Provider<SharingHttp>((ref) {
  return ref.read(apiClientProvider);
});

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((
  ref,
) {
  return PushRegistrationService(
    notificationService: ref.read(notificationServiceProvider),
    sharingHttp: ref.read(sharingHttpProvider),
  );
});

final reelRepositoryProvider = ChangeNotifierProvider<ReelRepository>((ref) {
  return ReelRepository(
    ref.read(apiClientProvider),
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
  return MapViewModel(ref.read(mapHttpProvider));
});

final reelFiltersViewModelProvider =
    ChangeNotifierProvider<ReelFiltersViewModel>((ref) {
      return ReelFiltersViewModel(ref.read(reelRepositoryProvider));
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
  return FoldersViewModel(ref.read(foldersHttpProvider));
});

final entitlementsViewModelProvider =
    ChangeNotifierProvider<EntitlementsViewModel>((ref) {
      return EntitlementsViewModel(
        ref.read(accountHttpProvider),
        ref.read(authServiceProvider),
        ref.read(reelRepositoryProvider),
        ref.read(homeViewModelProvider),
        ref.read(mapViewModelProvider),
        ref.read(reelFiltersViewModelProvider),
        ref.read(discoverViewModelProvider),
        ref.read(searchViewModelProvider),
      );
    });

final processingJobsViewModelProvider =
    ChangeNotifierProvider<ProcessingJobsViewModel>((ref) {
      return ProcessingJobsViewModel(
        ref.read(reelRepositoryProvider),
        // A finished job means there is a real reel to fetch, so reuse the same
        // content reload the app already runs on resume.
        // Awaited by the view model: each placeholder holds its place until
        // the card that replaces it is in the grid.
        onJobsFinished: (readyReels) async {
          if (readyReels.isNotEmpty) {
            final repository = ref.read(reelRepositoryProvider);
            for (final reel in readyReels) {
              repository.insertReel(reel);
            }
            return;
          }
          // The job finished without its reel attached, so there is nothing to
          // swap in and the grid has to be refetched after all.
          await ref
              .read(entitlementsViewModelProvider)
              .refresh(reloadContent: true);
        },
      );
    });

final userStateCoordinatorProvider = Provider<UserStateCoordinator>((ref) {
  return UserStateCoordinator(
    searchViewModel: ref.read(searchViewModelProvider),
    reelFiltersViewModel: ref.read(reelFiltersViewModelProvider),
    mapViewModel: ref.read(mapViewModelProvider),
    homeViewModel: ref.read(homeViewModelProvider),
    discoverViewModel: ref.read(discoverViewModelProvider),
    reelRepository: ref.read(reelRepositoryProvider),
    entitlementsViewModel: ref.read(entitlementsViewModelProvider),
    processingJobsViewModel: ref.read(processingJobsViewModelProvider),
  );
});
