import 'package:app_links/app_links.dart';

import 'package:reelpin/utils/app_logger.dart';

/// Holds the URL the app was launched with until something can route it.
///
/// A cold start goes splash -> session bootstrap -> AppShell, and only the
/// shell knows how to open a collection. `getInitialLink()` reports the launch
/// URL once, so asking for it inside the shell races that gating: if the shell
/// mounts late the link is already gone and the user lands on Home instead of
/// the collection they tapped.
///
/// Capturing it in bootstrap, before any of that, makes the link independent of
/// how long auth takes.
class PendingDeepLink {
  PendingDeepLink._();

  static Uri? _uri;

  /// Called from bootstrap, as early as possible.
  static Future<void> capture() async {
    try {
      _uri = await AppLinks().getInitialLink();
    } catch (e) {
      AppLogger.error('Initial deep link capture skipped: $e');
    }
  }

  /// Returns the captured link once and clears it, so a rebuild of the shell
  /// cannot reopen the same collection a second time.
  static Uri? take() {
    final uri = _uri;
    _uri = null;
    return uri;
  }
}
