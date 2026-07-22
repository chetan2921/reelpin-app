import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/core/config/supabase_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses the Android application ID for the OAuth callback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(
      SupabaseConfig.redirectUrl,
      'com.chetanjain.reelpin://login-callback',
    );
  });

  test('uses the iOS bundle ID for the OAuth callback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(SupabaseConfig.redirectUrl, 'com.chetan.reelpin://login-callback');
  });
}
