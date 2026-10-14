import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';

/// How a paywall visit ended. [unavailable] means it never opened (not
/// configured, signed out, the store or RevenueCat failing), which the user
/// should hear about; [dismissed] means they closed it.
enum PaywallOutcome { unlocked, dismissed, unavailable }

/// The app's only door to RevenueCat.
///
/// Purchases belong to the Supabase user id: a subscription bought on one
/// device follows the account to the next, and the backend looks it up by
/// the id it already knows. A purchase made under any other RevenueCat id
/// would be paid for but never unlock anything, so [presentPaywall] refuses
/// to open until RevenueCat holds the signed-in user's id.
///
/// Every call is a no-op when RevenueCat is not configured for this build,
/// the way Linkrunner falls back when it has no token.
class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  Future<void>? _ready;
  bool _configured = false;
  String? _userId;

  /// Safe to call more than once; every other call awaits it, so the auth
  /// listener firing before bootstrap finishes cannot skip the log-in.
  Future<void> configure() => _ready ??= _configure();

  Future<void> _configure() async {
    if (!RevenueCatConfig.isConfigured) return;
    try {
      await Purchases.configure(
        PurchasesConfiguration(RevenueCatConfig.apiKey),
      );
      _configured = true;
    } catch (e) {
      AppLogger.error('RevenueCat configure failed: $e');
    }
  }

  /// Called on every auth change: the signed-in user's id, or null.
  Future<void> syncUser(String? userId) async {
    _userId = (userId == null || userId.isEmpty) ? null : userId;
    await configure();
    if (!_configured) return;
    try {
      // Re-read after the await: a newer auth change may have landed.
      final current = _userId;
      if (current != null) {
        // Auth also fires on every hourly token refresh; only a different
        // user is worth a RevenueCat round trip.
        if (await Purchases.appUserID != current) {
          await Purchases.logIn(current);
        }
      } else if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
    } catch (e) {
      AppLogger.error('RevenueCat user sync failed: $e');
    }
  }

  /// Shows the paywall attached to RevenueCat's current offering.
  Future<PaywallOutcome> presentPaywall() async {
    await configure();
    final userId = _userId;
    if (!_configured || userId == null) return PaywallOutcome.unavailable;
    try {
      if (await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
      return switch (await RevenueCatUI.presentPaywall()) {
        PaywallResult.purchased ||
        PaywallResult.restored => PaywallOutcome.unlocked,
        PaywallResult.error => PaywallOutcome.unavailable,
        PaywallResult.cancelled ||
        PaywallResult.notPresented => PaywallOutcome.dismissed,
      };
    } catch (e) {
      AppLogger.error('RevenueCat paywall failed: $e');
      return PaywallOutcome.unavailable;
    }
  }

  /// RevenueCat's Customer Center: cancel, change plan, restore, refund.
  /// False when it could not be opened.
  Future<bool> manageSubscription() async {
    await configure();
    if (!_configured) return false;
    try {
      await RevenueCatUI.presentCustomerCenter();
      return true;
    } catch (e) {
      AppLogger.error('RevenueCat customer center failed: $e');
      return false;
    }
  }
}
