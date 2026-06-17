import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void resetRootNavigatorToAppEntry() {
  appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}
