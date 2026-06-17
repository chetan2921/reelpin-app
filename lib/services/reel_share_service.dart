import 'package:flutter/services.dart';

class ReelShareService {
  ReelShareService._();

  static const MethodChannel _channel = MethodChannel(
    'com.chetanjain.reelpin/reel_share',
  );

  static Future<void> shareReelCard({
    required Uint8List pngBytes,
    required String text,
    required String subject,
  }) {
    return _channel.invokeMethod<void>('shareReelCard', {
      'pngBytes': pngBytes,
      'text': text,
      'subject': subject,
    });
  }
}
