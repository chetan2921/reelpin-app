import 'package:flutter/material.dart';

/// Neo-brutalism colour palette and the context-aware colour helpers built on
/// it. Decorations, shadows, and [ThemeData] live in `app_theme.dart`.
class AppColors {
  AppColors._();

  // ── Core ──
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ── Primary Bold (loud, saturated) ──
  static const Color yellow = Color(0xFFFFD600);
  static const Color blue = Color(0xFF2962FF);
  static const Color red = Color(0xFFFF3D00);

  // ── Neon Accents ──
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color hotPink = Color(0xFFFF00FF);
  static const Color cyan = Color(0xFF00FFFF);

  // ── Flat Solid ──
  static const Color orange = Color(0xFFFF6F00);
  static const Color lime = Color(0xFFAEEA00);
  static const Color purple = Color(0xFF6A1B9A);
  static const Color darkTeal = Color(0xFF0D6F69);

  // ── Semantic Shortcuts ──
  static const Color background = white;
  static const Color surface = white;
  static const Color surfaceElevated = Color(0xFFF5F5F5);
  static const Color accent = yellow;
  static const Color accentSoft = Color(0xFFFFF9C4);
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF444444);
  static const Color textTertiary = Color(0xFF888888);
  static const Color border = black;
  static const Color positive = neonGreen;
  static const Color destructive = Color(0xFFFF0000);
  static const Color warning = orange;

  // ── Backwards-compatible aliases ──
  // These map old names to new brutalist roles so nothing breaks
  static const Color heiSeBlack = white;
  static const Color blueWhale = white;
  static const Color blueWhaleLight = Color(0xFFF0F0F0);
  static const Color siestaTan = black;
  static const Color stellarStrawberry = red;
  static const Color grauzone = Color(0xFF444444);
  static const Color picoEggplant = purple;
  static const Color midnightPlum = white;
  static const Color deepIndigo = white;
  static const Color cardDark = white;
  static const Color cream = black;
  static const Color dustyRose = red;
  static const Color heiSeBlackLight = white;
  static const Color blueWhaleDark = Color(0xFFE0E0E0);

  // ── Dynamic Color Helpers ──
  static Color bg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1A1A)
        : white;
  }

  static Color fg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? white : black;
  }

  static Color textSec(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFCCCCCC)
        : textSecondary;
  }

  static Color surfaceElevatedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : surfaceElevated;
  }

  // ── Category Colors (rotating brutalist palette) ──
  static const List<Color> _categoryPalette = [
    blue,
    neonGreen,
    red,
    yellow,
    hotPink,
    cyan,
    orange,
    lime,
    purple,
    Color(0xFF00E5FF),
  ];

  static Color getCategoryColor(String category) {
    final normalized = category.trim().toLowerCase();
    final index = _stablePaletteIndex(normalized);
    return _categoryPalette[index];
  }

  static int _stablePaletteIndex(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash % _categoryPalette.length;
  }
}
