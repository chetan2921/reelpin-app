import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool small;

  const CategoryBadge({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCategoryColor(category);

    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(50), color.withAlpha(25)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(40), width: 0.5),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withAlpha(70), color.withAlpha(35)],
                )
              : null,
          color: isSelected ? null : AppTheme.deepIndigo.withAlpha(140),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? color.withAlpha(120)
                : AppTheme.cream.withAlpha(15),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? color : AppTheme.cream.withAlpha(160),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
