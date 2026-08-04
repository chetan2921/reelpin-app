import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:reelpin/core/design/app_spacing.dart';

class AppLayout {
  AppLayout._(this.size, this.padding);

  final Size size;
  final EdgeInsets padding;

  static AppLayout of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return AppLayout._(mediaQuery.size, mediaQuery.padding);
  }

  double get width => size.width;
  double get height => size.height;
  double get shortestSide => math.min(width, height);

  bool get isCompactWidth => width < 380;
  bool get isCompactHeight => height < 760;
  bool get isCompact => isCompactWidth || isCompactHeight;
  bool get isTablet => width >= 600;

  double scale(
    double value, {
    double minFactor = 0.82,
    double maxFactor = 1.18,
    bool useHeight = false,
  }) {
    final rawFactor = useHeight ? height / 844 : shortestSide / 390;
    final factor = rawFactor.clamp(minFactor, maxFactor).toDouble();
    return value * factor;
  }

  double inset(double value) => scale(value, minFactor: 0.82, maxFactor: 1.22);

  double gap(double value) =>
      scale(value, minFactor: 0.72, maxFactor: 1.18, useHeight: true);

  double font(
    double value, {
    double minFactor = 0.88,
    double maxFactor = 1.14,
  }) => scale(value, minFactor: minFactor, maxFactor: maxFactor);

  EdgeInsets pagePadding({
    double horizontal = AppSpacing.xl,
    double top = AppSpacing.xl,
    double bottom = AppSpacing.xxl,
  }) {
    return EdgeInsets.fromLTRB(
      inset(horizontal),
      gap(top),
      inset(horizontal),
      gap(bottom),
    );
  }

  int gridColumns({
    int compact = 2,
    int regular = 2,
    int wide = 3,
    int tablet = 4,
  }) {
    if (width >= 960) return tablet;
    if (width >= 680) return wide;
    return width < 360 ? compact : regular;
  }

  double gridAspect({
    double compact = 0.76,
    double regular = 0.80,
    double wide = 0.88,
    double tablet = 0.94,
  }) {
    if (width >= 960) return tablet;
    if (width >= 680) return wide;
    return width < 360 ? compact : regular;
  }

  double clampWidth(
    double fraction, {
    required double min,
    required double max,
  }) => (width * fraction).clamp(min, max).toDouble();
}
