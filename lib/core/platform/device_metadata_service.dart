import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:reelpin/core/logging/app_logger.dart';

class DeviceMetadata {
  const DeviceMetadata({
    required this.appVersion,
    required this.appBuild,
    required this.timezone,
    required this.locale,
  });

  final String appVersion;
  final String appBuild;
  final String timezone;
  final String locale;
}

class DeviceMetadataService {
  const DeviceMetadataService();

  static const _channel = MethodChannel(
    'com.chetanjain.reelpin/device_metadata',
  );

  Future<DeviceMetadata> load() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final values = await _channel.invokeMapMethod<String, dynamic>('get');
        if (values != null) {
          return DeviceMetadata(
            appVersion: _value(values['appVersion']),
            appBuild: _value(values['appBuild']),
            timezone: _value(values['timezone']),
            locale: _value(values['locale']),
          );
        }
      } catch (e) {
        AppLogger.error('Device metadata lookup skipped: $e');
      }
    }

    return DeviceMetadata(
      appVersion: 'unknown',
      appBuild: '0',
      timezone: DateTime.now().timeZoneName,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
    );
  }

  String _value(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? 'unknown' : normalized;
  }
}
