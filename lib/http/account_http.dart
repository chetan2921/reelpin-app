import 'package:reelpin/features/account/domain/library_stats.dart';
import 'package:reelpin/features/account/domain/user_entitlement.dart';

abstract interface class AccountApi {
  Future<EntitlementsResponse> getAccountEntitlements({required String userId});

  Future<LibraryStats> getLibraryStats();

  Future<void> deleteAccount();
}
