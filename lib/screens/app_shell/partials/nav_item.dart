part of '../app_shell.dart';

/// A nav slot is either a HugeIcons glyph or an image asset. The pin is an
/// asset because it is full-colour artwork — which is also why it is never
/// tinted for the selected state the way the glyphs are.
class _NavItem {
  final List<List<dynamic>>? icon;
  final String? assetPath;
  final String label;

  const _NavItem({this.icon, this.assetPath, required this.label})
    : assert(
        icon != null || assetPath != null,
        'A nav item needs either a glyph or an asset',
      );
}
