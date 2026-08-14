import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';

/// The app's one confirmation dialog.
///
/// Every destructive prompt used to draw its own: a stock Material dialog on
/// Home, a hand-built card in Collections, another in Map, and the reel
/// detail's brutal square. This is that last one, made shared.
///
/// Returns true only when the user picks the confirm action; dismissing by
/// tapping outside returns null, so callers should compare against true.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'DELETE',
  String cancelLabel = 'CANCEL',
  bool isDestructive = true,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.bg(dialogContext),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(
          color: AppColors.fg(dialogContext),
          width: AppTheme.borderWidth,
        ),
      ),
      title: Text(
        title.toUpperCase(),
        style: GoogleFonts.spaceMono(
          color: AppColors.fg(dialogContext),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.spaceMono(
          color: AppColors.textSec(dialogContext),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            cancelLabel.toUpperCase(),
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(dialogContext),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDestructive ? AppColors.destructive : AppColors.yellow,
              border: Border.all(color: AppColors.fg(dialogContext), width: 2),
              boxShadow: AppTheme.brutalShadowSmall(dialogContext),
            ),
            child: Text(
              confirmLabel.toUpperCase(),
              style: GoogleFonts.spaceMono(
                color: isDestructive ? AppColors.white : AppColors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
