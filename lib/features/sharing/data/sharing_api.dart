import 'package:reelpin/features/sharing/domain/share_resolve_response.dart';

abstract interface class SharingApi {
  Future<ShareResolveResponse> resolveSharePayload({
    required String rawPayloadText,
    required String platform,
    Map<String, dynamic> metadata = const {},
  });

  Future<void> registerPushToken({
    required String userId,
    required String token,
    required String platform,
    required String appVersion,
    required String appBuild,
    required String timezone,
    required String locale,
  });

  Future<void> unregisterPushToken({required String token});

  Future<void> recordNotificationOpened({required String notificationId});

  Future<String> mintShareToken();

  Future<void> revokeShareToken();
}
