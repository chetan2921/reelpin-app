import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ──
  static const Color midnightPlum = Color(0xFF190019);
  static const Color deepIndigo = Color(0xFF2B124C);
  static const Color amethyst = Color(0xFF522B5B);
  static const Color mauve = Color(0xFF854F6C);
  static const Color dustyRose = Color(0xFFDFB6B2);
  static const Color cream = Color(0xFFFBE4D8);

  // ── Semantic aliases ──
  static const Color surfaceDark = midnightPlum;
  static const Color cardDark = Color(0xFF2B124C); // deepIndigo
  static const Color accentGlow = dustyRose;
  static const Color seedColor = amethyst;

  // ── Category Colors (warm-harmonized) ──
  static const Map<String, Color> categoryColors = {
    'Food': mauve,
    'Travel': dustyRose,
    'Fitness': amethyst,
    'Finance': cream,
    'Study': mauve,
    'Tech': dustyRose,
    'Fashion': amethyst,
    'Entertainment': mauve,
    'Health': dustyRose,
    'Other': cream,
  };

  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? categoryColors['Other']!;
  }

  // ── Gradient helpers ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amethyst, mauve],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mauve, dustyRose],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnightPlum, deepIndigo],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dustyRose, cream],
  );

  // ── Glass decoration helper ──
  static BoxDecoration glassDecoration({
    double opacity = 0.12,
    double borderRadius = 20,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: deepIndigo.withAlpha((opacity * 255).round()),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? cream.withAlpha(20), width: 1),
      boxShadow: [
        BoxShadow(
          color: midnightPlum.withAlpha(60),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ── Dark Theme ──
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: amethyst,
      brightness: Brightness.dark,
      surface: midnightPlum,
      primary: dustyRose,
      secondary: mauve,
      tertiary: cream,
      onSurface: cream,
      onPrimary: midnightPlum,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: midnightPlum,
      appBarTheme: AppBarThemeData(
        backgroundColor: midnightPlum,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: cream,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: cream),
      ),
      cardTheme: CardThemeData(
        color: deepIndigo.withAlpha(180),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cream.withAlpha(15)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: deepIndigo.withAlpha(200),
        indicatorColor: mauve.withAlpha(80),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: dustyRose,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: cream);
          }
          return IconThemeData(color: cream.withAlpha(120));
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: deepIndigo.withAlpha(160),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cream.withAlpha(15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dustyRose.withAlpha(120), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: cream.withAlpha(80)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: deepIndigo.withAlpha(140),
        selectedColor: mauve.withAlpha(80),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cream,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: cream.withAlpha(15)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: mauve,
        foregroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: dustyRose,
      ),
      dividerTheme: DividerThemeData(color: cream.withAlpha(15), thickness: 1),
    );
  }
}
