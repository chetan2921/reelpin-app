part of '../how_to_use_screen.dart';

/// One tap-through step of the share walkthrough.
///
/// Every hotspot figure is a fraction of the screenshot rather than a pixel
/// offset, so a capture can be re-exported at any resolution and still line up.
/// [hotspotX] / [hotspotWidth] are fractions of the image's width;
/// [hotspotY] / [hotspotHeight] are fractions of its height.
class _HowToStep {
  const _HowToStep({
    required this.assetPath,
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
    required this.hotspotX,
    required this.hotspotY,
    required this.hotspotWidth,
    required this.hotspotHeight,
    required this.aspectRatio,
    this.hotspotCorner = _kCircleCorner,
  });

  final String assetPath;
  final String label;
  final String title;
  final String body;
  final Color accent;

  /// Centre of the highlight already drawn into the capture.
  final double hotspotX;
  final double hotspotY;

  /// Size of that highlight.
  final double hotspotWidth;
  final double hotspotHeight;

  /// Corner rounding as a fraction of the shorter side. The default traces a
  /// circle; iOS's app row is highlighted with a rounded rectangle instead.
  final double hotspotCorner;

  final double aspectRatio;
}

/// A corner radius of half the shorter side turns the rounded rectangle the
/// pulse draws into a plain circle.
const double _kCircleCorner = 0.5;

/// Every capture, on both platforms, is 784 x 1600.
const double _kGuideAspectRatio = 784 / 1600;
