import 'package:reelpin/services/device_metadata_service.dart';
import 'package:reelpin/services/notifications/notification_service.dart';
import 'package:reelpin/http/sharing_http.dart';
import 'package:reelpin/services/sharing/share_handoff_service.dart';

class PushRegistrationService {
  PushRegistrationService({
    required NotificationService notificationService,
    required SharingHttp sharingHttp,
    DeviceMetadataService deviceMetadataService = const DeviceMetadataService(),
  }) : _notificationService = notificationService,
       _sharingHttp = sharingHttp,
       _deviceMetadataService = deviceMetadataService;

  final NotificationService _notificationService;
  final SharingHttp _sharingHttp;
  final DeviceMetadataService _deviceMetadataService;

  Future<String?> register({
    required String userId,
    String? candidateToken,
    Duration apnsTimeout = const Duration(seconds: 5),
  }) async {
    await _notificationService.initialize(requestPermissions: false);
    final normalizedCandidate = candidateToken?.trim();
    final token = normalizedCandidate != null && normalizedCandidate.isNotEmpty
        ? normalizedCandidate
        : await _notificationService.getFcmToken(apnsTimeout: apnsTimeout);
    if (token == null || token.trim().isEmpty) return null;

    final normalizedToken = token.trim();
    _notificationService.rememberFcmToken(normalizedToken);
    final metadata = await _deviceMetadataService.load();
    await _sharingHttp.registerPushToken(
      userId: userId,
      token: normalizedToken,
      platform: _notificationService.currentPlatform,
      appVersion: metadata.appVersion,
      appBuild: metadata.appBuild,
      timezone: metadata.timezone,
      locale: metadata.locale,
    );
    await ShareHandoffService.instance.syncPushToken(
      token: normalizedToken,
      platform: _notificationService.currentPlatform,
    );
    return normalizedToken;
  }

  Future<void> unregisterCurrentDevice() async {
    await _notificationService.initialize(requestPermissions: false);
    final token = await _notificationService.getCurrentFcmToken();
    if (token == null || token.trim().isEmpty) return;
    await _sharingHttp.unregisterPushToken(token: token.trim());
  }

  Future<void> recordNotificationOpened(String notificationId) {
    return _sharingHttp.recordNotificationOpened(
      notificationId: notificationId,
    );
  }
}
