import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reelpin/reelpin_app.dart';
import 'package:reelpin/env.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/services/notifications/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  _configureImageCache();
  await SupabaseConfig.loadLocalConfig();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      AppLogger.error('Firebase initialization skipped: $e');
    }
  }

  final isSupabaseConfigured = SupabaseConfig.isConfigured;
  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(
    ProviderScope(
      child: ReelPinApp(isSupabaseConfigured: isSupabaseConfigured),
    ),
  );
}

/// Gives the grid enough room to hold a few screens of thumbnails in memory.
///
/// The default 100 MB budget is spent quickly by a scrolling grid, and every
/// eviction shows up as a thumbnail visibly reloading when the user scrolls
/// back. Thumbnails are decoded down to their painted size (see the thumbnail
/// widget in ReelCard), so this headroom buys many more images rather than a
/// few large ones — and anything still evicted comes back off disk, not the
/// network.
void _configureImageCache() {
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
}
