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

  // ── Dynamic Color Helpers ──
  static Color bg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : white;
  }
  
  static Color fg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? white : black;
  }

  static Color textSec(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCCCCCC) : textSecondary;
  }

  static Color surfaceElevatedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : surfaceElevated;
  }

  // ── Hard shadow ──
  static const Offset shadowOffset = Offset(4, 4);
  
  static List<BoxShadow> brutalShadow(BuildContext context) => [
    BoxShadow(
      color: fg(context),
      offset: shadowOffset,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> brutalShadowSmall(BuildContext context) => [
    BoxShadow(
      color: fg(context),
      offset: const Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> inkShadow = [
    BoxShadow(
      color: black,
      offset: shadowOffset,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> inkShadowSmall = [
    BoxShadow(
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
  static BoxDecoration brutalBox(
    BuildContext context, {
    Color? color,
    double borderRadius = 0,
    bool shadow = true,
    double borderW = borderWidth,
  }) {
    return BoxDecoration(
      color: color ?? bg(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: fg(context), width: borderW),
      boxShadow: shadow ? brutalShadow(context) : null,
    );
  }

  // ── Brutal Card Decoration ──
  static BoxDecoration brutalCard(
    BuildContext context, {
    Color? color,
    double borderRadius = 0,
  }) {
    return BoxDecoration(
      color: color ?? bg(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: fg(context), width: borderWidth),
      boxShadow: brutalShadow(context),
    );
  }

  // ── Backwards-compatible aliases ──
  static BoxDecoration glassDecoration(
    BuildContext context, {
    double opacity = 0.7,
    double borderRadius = 0,
  }) {
    return brutalBox(context, borderRadius: borderRadius);
  }

  static BoxDecoration cardDecoration(BuildContext context, {double borderRadius = 0}) {
    return brutalCard(context, borderRadius: borderRadius);
  }

  // ══════════════════════════════════════════════════
  //  BRUTAL THEME DATA
  // ══════════════════════════════════════════════════

  static ThemeData get brutalTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final bgColor = isDark ? const Color(0xFF1A1A1A) : white;
    final fgColor = isDark ? white : black;
    final tSecondary = isDark ? const Color(0xFFCCCCCC) : textSecondary;
    
    final headingText = GoogleFonts.spaceMonoTextTheme();
    final bodyText = GoogleFonts.spaceMonoTextTheme();

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: fgColor,
        secondary: yellow,
        tertiary: blue,
        surface: bgColor,
        onSurface: fgColor,
        onPrimary: bgColor,
        onSecondary: fgColor,
        onTertiary: bgColor,
        error: destructive,
        onError: white,
      ),
      scaffoldBackgroundColor: bgColor,
      textTheme: bodyText.copyWith(
        displayLarge: headingText.displayLarge?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w900,
        ),
        headlineLarge: headingText.headlineLarge?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: headingText.headlineMedium?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: headingText.titleLarge?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: bodyText.bodyLarge?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: bodyText.bodyMedium?.copyWith(
          color: fgColor,
        ),
        bodySmall: bodyText.bodySmall?.copyWith(
          color: tSecondary,
        ),
        labelLarge: bodyText.labelLarge?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: bodyText.labelMedium?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: bodyText.labelSmall?.copyWith(
          color: tSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: fgColor,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: fgColor, size: 24),
      ),
      cardTheme: CardThemeData(
        color: bgColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(color: fgColor, width: borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgColor,
        indicatorColor: yellow,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceMono(
            fontWeight: FontWeight.w700,
            color: fgColor,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: black, size: 24); // Keep black icon inside yellow chip
          }
          return IconThemeData(color: fgColor, size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: fgColor, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: fgColor, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(0),
          borderSide: BorderSide(color: blue, width: borderWidth),
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
        backgroundColor: isDark ? const Color(0xFF222222) : white,
        selectedColor: yellow,
        labelStyle: GoogleFonts.spaceMono(
          fontWeight: FontWeight.w700,
          color: fgColor,
          fontSize: 12,
        ),
        secondaryLabelStyle: GoogleFonts.spaceMono(
          fontWeight: FontWeight.w700,
          color: black, // Black inside yellow
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        side: BorderSide(color: fgColor, width: thinBorderWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: yellow,
        foregroundColor: black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(color: fgColor, width: borderWidth),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: fgColor,
      ),
      dividerTheme: DividerThemeData(
        color: fgColor,
        thickness: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgColor,
        contentTextStyle: GoogleFonts.spaceMono(
          color: fgColor,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(color: fgColor, width: borderWidth),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(color: fgColor, width: borderWidth),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgColor,
      ),
    );
  }
}
