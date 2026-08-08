import 'package:reelpin/data_models/account/library_stats.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';

abstract interface class AccountHttp {
  Future<EntitlementsResponse> getAccountEntitlements({required String userId});

  Future<LibraryStats> getLibraryStats();

  Future<void> deleteAccount();
}
