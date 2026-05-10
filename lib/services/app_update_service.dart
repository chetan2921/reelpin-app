import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  AppUpdateService._();

  static Future<void> checkForImmediateUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      final canUpdate =
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable &&
          updateInfo.immediateUpdateAllowed;
      if (!canUpdate) return;

      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('In-app update check skipped: $e');
    }
  }
}
