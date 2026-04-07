import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/api_config.dart';

class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════
  //  NEO-BRUTALISM COLOR PALETTE
  // ══════════════════════════════════════════════════

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

  // ── Border specs ──
  static const double borderWidth = 3.0;
  static const double thinBorderWidth = 2.0;

  // ── Hard shadow ──
  static const Offset shadowOffset = Offset(4, 4);
  static List<BoxShadow> get brutalShadow => [
    const BoxShadow(
      color: black,
      offset: shadowOffset,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get brutalShadowSmall => [
    const BoxShadow(
      color: black,
      offset: Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

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

  static Color getCategoryColor(String categoryOrSub) {
    int index = ApiConfig.broadCategories.indexOf(categoryOrSub);
    
    if (index == -1) {
      for (int i = 0; i < ApiConfig.broadCategories.length; i++) {
        final broad = ApiConfig.broadCategories[i];
        if (ApiConfig.categoryGroups[broad]?.contains(categoryOrSub) ?? false) {
          index = i;
          break;
        }
      }
    }
    
    if (index == -1) {
      index = categoryOrSub.hashCode.abs() % _categoryPalette.length;
    }
    
    return _categoryPalette[index % _categoryPalette.length];
  }

  // ── Brutal Box Decoration ──
  static BoxDecoration brutalBox({
    Color color = white,
    double borderRadius = 0,
    bool shadow = true,
    double borderW = borderWidth,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: black, width: borderW),
      boxShadow: shadow ? brutalShadow : null,
    );
  }

  // ── Brutal Card Decoration ──
  static BoxDecoration brutalCard({
    Color color = white,
    double borderRadius = 0,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: black, width: borderWidth),
      boxShadow: brutalShadow,
    );
  }

  // ── Backwards-compatible aliases ──
  static BoxDecoration glassDecoration({
    double opacity = 0.7,
    double borderRadius = 0,
  }) {
    return brutalBox(borderRadius: borderRadius);
  }

  static BoxDecoration cardDecoration({double borderRadius = 0}) {
    return brutalCard(borderRadius: borderRadius);
  }

  // ══════════════════════════════════════════════════
  //  BRUTAL THEME DATA
  // ══════════════════════════════════════════════════

  static ThemeData get brutalTheme {
    final headingText = GoogleFonts.spaceMonoTextTheme();
    final bodyText = GoogleFonts.spaceMonoTextTheme();

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: black,
        secondary: yellow,
        tertiary: blue,
        surface: white,
        onSurface: black,
        onPrimary: white,
        error: destructive,
      ),
      scaffoldBackgroundColor: white,
      textTheme: bodyText.copyWith(
        displayLarge: headingText.displayLarge?.copyWith(
          color: black,
          fontWeight: FontWeight.w900,
        ),
        headlineLarge: headingText.headlineLarge?.copyWith(
          color: black,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: headingText.headlineMedium?.copyWith(
          color: black,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: headingText.titleLarge?.copyWith(
          color: black,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: bodyText.bodyLarge?.copyWith(
          color: black,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: bodyText.bodyMedium?.copyWith(
          color: black,
        ),
        bodySmall: bodyText.bodySmall?.copyWith(
          color: textSecondary,
        ),
        labelLarge: bodyText.labelLarge?.copyWith(
          color: black,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: bodyText.labelMedium?.copyWith(
          color: black,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: bodyText.labelSmall?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: black,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: black, size: 24),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: black, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: yellow,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceMono(
            fontWeight: FontWeight.w700,
            color: black,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: black, size: 24);
          }
          return const IconThemeData(color: black, size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: black, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: black, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: const BorderSide(color: blue, width: borderWidth),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.spaceMono(
          color: textTertiary,
          fontSize: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: white,
        selectedColor: yellow,
        labelStyle: GoogleFonts.spaceMono(
          fontWeight: FontWeight.w700,
          color: black,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        side: const BorderSide(color: black, width: thinBorderWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: yellow,
        foregroundColor: black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: black, width: borderWidth),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: black,
      ),
      dividerTheme: const DividerThemeData(
        color: black,
        thickness: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: white,
        contentTextStyle: GoogleFonts.spaceMono(
          color: black,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: black, width: borderWidth),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: black, width: borderWidth),
        ),
      ),
    );
  }

  // Keep old name working
  static ThemeData get darkTheme => brutalTheme;
}
