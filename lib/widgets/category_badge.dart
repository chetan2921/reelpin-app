import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool small;
  final double customHeight;
  final double customFontSize;

  const CategoryBadge({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
    this.small = false,
    this.customHeight = 40,
    this.customFontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCategoryColor(category);

    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppTheme.black, width: 2),
        ),
        child: Text(
          category.toUpperCase(),
          style: GoogleFonts.spaceMono(
            color: _contrastText(color),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: customHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.yellow : AppTheme.white,
          border: Border.all(
            color: AppTheme.black,
            width: AppTheme.thinBorderWidth,
          ),
          boxShadow: isSelected ? AppTheme.brutalShadowSmall : null,
        ),
        child: Center(
          widthFactor: 1.0,
          child: Text(
            category.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: customFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Color _contrastText(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? AppTheme.black : AppTheme.white;
  }
}
