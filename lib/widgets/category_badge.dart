import 'package:flutter/material.dart';

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
    this.customHeight = 48,
    this.customFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCategoryColor(category);

    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.midnightPlum.withAlpha(120),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withAlpha(180), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                category,
                style: TextStyle(
                  color: AppTheme.cream.withAlpha(200),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        height: customHeight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withAlpha(70)
              : AppTheme.deepIndigo.withAlpha(150),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : AppTheme.cream.withAlpha(40),
            width: 1.5,
          ),
        ),
        child: Center(
          widthFactor: 1.0,
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.cream
                  : AppTheme.cream.withAlpha(220),
              fontSize: customFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
