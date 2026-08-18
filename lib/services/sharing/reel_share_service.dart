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

  /// Opens the OS share sheet with text only — used for collection share and
  /// invite links, which have no card image to attach.
  static Future<void> shareText({
    required String text,
    required String subject,
  }) {
    return _channel.invokeMethod<void>('shareText', {
      'text': text,
      'subject': subject,
    });
  }
}
