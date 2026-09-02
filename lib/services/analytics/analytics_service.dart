import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Reporting for analytics events and uncaught errors.
///
/// Static rather than a provider because [installErrorHandlers] runs in
/// `bootstrap()` before there is a `ProviderScope` to read from.
class AnalyticsService {
  AnalyticsService._();

  static bool _ready = false;

  /// Routes uncaught errors to Crashlytics.
  ///
  /// Call this first thing in `bootstrap()`. Firebase is started there without
  /// being awaited, so handlers installed only after initialization would miss
  /// anything that failed during launch — the window this exists to cover.
  /// Reports raised before [markReady] are logged locally instead of dropped.
  static void installErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (_ready) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else {
        AppLogger.error('Flutter error before Crashlytics was ready: $details');
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_ready) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        AppLogger.error('Uncaught error before Crashlytics was ready: $error');
      }
      return true;
    };
  }

  /// Marks Firebase as initialized, releasing reporting.
  static void markReady() => _ready = true;

  static Future<void> log(
    AnalyticsEvent event, {
    Map<String, Object>? parameters,
  }) async {
    if (!_ready) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: event.wireName,
        parameters: parameters,
      );
    } catch (e) {
      AppLogger.error('Analytics event ${event.wireName} failed: $e');
    }
  }

  /// Reports an error the app caught and handled.
  static Future<void> recordError(Object error, StackTrace? stack) async {
    if (!_ready) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: false,
      );
    } catch (e) {
      AppLogger.error('Crashlytics report failed: $e');
    }
  }
}
