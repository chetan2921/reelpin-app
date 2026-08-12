import 'package:flutter/foundation.dart';
import 'package:linkrunner/linkrunner.dart';

import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Thin wrapper over the Linkrunner SDK for collection share and invite links.
///
/// Two jobs:
///  * resolve an incoming URL, since a Linkrunner short link carries the real
///    `/c/...` destination as attribution data rather than in its own path;
///  * surface the *deferred* link — the destination captured when someone
///    tapped a share link, installed from the store, and opened the app for the
///    first time. There is no incoming URL in that case, so without this the
///    new user lands on the home tab instead of the collection they tapped.
///
/// Every method is a safe no-op when [LinkrunnerConfig.isConfigured] is false,
/// so an unconfigured build behaves exactly as it did before the SDK existed.
/// Failures are logged and swallowed: attribution is never worth blocking a
/// link the app could otherwise handle itself.
class LinkrunnerService {
  LinkrunnerService._();

  static final LinkrunnerService instance = LinkrunnerService._();

  bool _initialised = false;

  @visibleForTesting
  bool get isInitialised => _initialised;

  Future<void> init() async {
    if (!LinkrunnerConfig.isConfigured || _initialised) return;
    try {
      await LinkRunner().init(
        LinkrunnerConfig.token,
        LinkrunnerConfig.secretKey,
        LinkrunnerConfig.keyId,
        false,
        kDebugMode,
      );
      _initialised = true;
    } catch (e) {
      AppLogger.error('Linkrunner init skipped: $e');
    }
  }

  /// Returns the URI the app should actually route to.
  ///
  /// Falls back to [incoming] whenever Linkrunner is off, does not recognise
  /// the link, or errors — a direct `https://reelpin.in/c/{token}` link must
  /// keep working with no SDK involved.
  Future<Uri> resolve(Uri incoming) async {
    if (!_initialised) return incoming;
    try {
      final result = await LinkRunner().handleDeeplink(incoming.toString());
      final resolved = result?.deeplink;
      if (result?.isLinkrunner == true &&
          resolved != null &&
          resolved.trim().isNotEmpty) {
        return Uri.tryParse(resolved.trim()) ?? incoming;
      }
    } catch (e) {
      AppLogger.error('Linkrunner deeplink resolve skipped: $e');
    }
    return incoming;
  }

  /// The destination captured before install, or null when this launch did not
  /// come from a link. Only meaningful on a first run after a store install.
  Future<Uri?> deferredLink() async {
    if (!_initialised) return null;
    try {
      final attribution = await LinkRunner().getAttributionData();
      final deeplink = attribution?.deeplink?.trim();
      if (deeplink == null || deeplink.isEmpty) return null;
      return Uri.tryParse(deeplink);
    } catch (e) {
      AppLogger.error('Linkrunner attribution lookup skipped: $e');
      return null;
    }
  }
}
