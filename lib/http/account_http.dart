import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';

abstract interface class AccountHttp {
  /// [sync] asks the backend to re-read RevenueCat first; the app sends it
  /// only right after a purchase, before the webhook may have landed.
  Future<EntitlementsResponse> getAccountEntitlements({
    required String userId,
    bool sync = false,
  });

  Future<LibraryStats> getLibraryStats();

  Future<void> deleteAccount();
}
