import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reelpin/app/reelpin_app.dart';
import 'package:reelpin/core/config/supabase_config.dart';
import 'package:reelpin/core/logging/app_logger.dart';
import 'package:reelpin/core/platform/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
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
