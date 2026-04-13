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
    final layout = AppLayout.of(context);

    if (small) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.inset(8),
          vertical: layout.gap(3),
        ),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppTheme.fg(context), width: 2),
        ),
        child: Text(
          category.toUpperCase(),
          style: GoogleFonts.spaceMono(
            color: _contrastText(color),
            fontSize: layout.font(9),
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
        height: layout.gap(customHeight),
        padding: EdgeInsets.symmetric(horizontal: layout.inset(14)),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.yellow : AppTheme.bg(context),
          border: Border.all(
            color: AppTheme.fg(context),
            width: AppTheme.thinBorderWidth,
          ),
          boxShadow: isSelected ? AppTheme.brutalShadowSmall(context) : null,
        ),
        child: Center(
          widthFactor: 1.0,
          child: Text(
            category.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: isSelected ? AppTheme.black : AppTheme.fg(context),
              fontSize: layout.font(customFontSize),
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
