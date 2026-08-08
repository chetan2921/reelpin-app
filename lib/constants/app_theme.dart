import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Border specs ──
  static const double borderWidth = 1;
  static const double thinBorderWidth = 1;

  // ── Hard shadow ──
  static const Offset shadowOffset = Offset(4, 4);

  static List<BoxShadow> brutalShadow(BuildContext context) => [
    BoxShadow(
      color: AppColors.fg(context),
      offset: shadowOffset,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> brutalShadowSmall(BuildContext context) => [
    BoxShadow(
      color: AppColors.fg(context),
      offset: const Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> inkShadow = [
    BoxShadow(
      color: AppColors.black,
      offset: shadowOffset,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> inkShadowSmall = [
    BoxShadow(
      color: AppColors.black,
      offset: Offset(3, 3),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  // ── Brutal Box Decoration ──
  static BoxDecoration brutalBox(
    BuildContext context, {
    Color? color,
    double borderRadius = 0,
    bool shadow = true,
    double borderW = borderWidth,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.bg(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.fg(context), width: borderW),
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
      color: color ?? AppColors.bg(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.fg(context), width: borderWidth),
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

  static BoxDecoration cardDecoration(
    BuildContext context, {
    double borderRadius = 0,
  }) {
    return brutalCard(context, borderRadius: borderRadius);
  }

  // ══════════════════════════════════════════════════
  //  BRUTAL THEME DATA
  // ══════════════════════════════════════════════════

  static ThemeData get brutalTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final bgColor = isDark ? const Color(0xFF1A1A1A) : AppColors.white;
    final fgColor = isDark ? AppColors.white : AppColors.black;
    final tSecondary = isDark
        ? const Color(0xFFCCCCCC)
        : AppColors.textSecondary;

    final headingText = GoogleFonts.spaceMonoTextTheme();
    final bodyText = GoogleFonts.spaceMonoTextTheme();

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: fgColor,
        secondary: AppColors.yellow,
        tertiary: AppColors.blue,
        surface: bgColor,
        onSurface: fgColor,
        onPrimary: bgColor,
        onSecondary: fgColor,
        onTertiary: bgColor,
        error: AppColors.destructive,
        onError: AppColors.white,
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
        bodyMedium: bodyText.bodyMedium?.copyWith(color: fgColor),
        bodySmall: bodyText.bodySmall?.copyWith(color: tSecondary),
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
        indicatorColor: AppColors.yellow,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceMono(
            fontWeight: FontWeight.w700,
            color: fgColor,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.black,
              size: 24,
            ); // Keep black icon inside yellow chip
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
          borderSide: BorderSide(color: AppColors.blue, width: borderWidth),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.spaceMono(
          color: AppColors.textTertiary,
          fontSize: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF222222) : AppColors.white,
        selectedColor: AppColors.yellow,
        labelStyle: GoogleFonts.spaceMono(
          fontWeight: FontWeight.w700,
          color: fgColor,
          fontSize: 12,
        ),
        secondaryLabelStyle: GoogleFonts.spaceMono(
          fontWeight: FontWeight.w700,
          color: AppColors.black, // Black inside yellow
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        side: BorderSide(color: fgColor, width: thinBorderWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(color: fgColor, width: borderWidth),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: fgColor),
      dividerTheme: DividerThemeData(color: fgColor, thickness: 2),
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
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: bgColor),
    );
  }
}
