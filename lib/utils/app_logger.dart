import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void debug(Object? message) {
    debugPrint(message?.toString());
  }

  static void info(Object? message) {
    debugPrint(message?.toString());
  }

  static void error(Object? message) {
    debugPrint(message?.toString());
  }
}
