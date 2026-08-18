import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/components/collections/add_to_collection_sheet.dart';

enum _ReelAction { addToCollection, delete }

/// Long-press menu for a reel card: send it to a collection, or delete it.
/// Ported from the folders branch's reel actions sheet.
Future<void> showReelActionsSheet(
  BuildContext context,
  Reel reel, {
  VoidCallback? onDelete,
}) async {
  final action = await showModalBottomSheet<_ReelAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final layout = AppLayout.of(context);
      return Container(
        padding: EdgeInsets.fromLTRB(
          layout.inset(24),
          layout.gap(18),
          layout.inset(24),
          layout.gap(24),
        ),
        decoration: BoxDecoration(color: AppColors.bg(context)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: layout.inset(40),
                  height: layout.gap(4),
                  color: AppColors.fg(context),
                ),
              ),
              SizedBox(height: layout.gap(18)),
              Text(
                'REEL ACTIONS',
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(17),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(8)),
              Text(
                reel.title.isEmpty
                    ? 'CHOOSE WHAT TO DO WITH THIS REEL.'
                    : reel.title,
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: layout.gap(18)),
              _ActionButton(
                label: 'ADD TO COLLECTION',
                color: AppColors.blue,
                icon: Icons.drive_file_move,
                onTap: () =>
                    Navigator.pop(context, _ReelAction.addToCollection),
              ),
              if (onDelete != null) ...[
                SizedBox(height: layout.gap(12)),
                _ActionButton(
                  label: 'DELETE FROM LIBRARY',
                  color: AppColors.destructive,
                  icon: Icons.delete_outline,
                  onTap: () => Navigator.pop(context, _ReelAction.delete),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted) return;
  switch (action) {
    case _ReelAction.addToCollection:
      await showAddToCollectionSheet(context, [reel.id]);
    case _ReelAction.delete:
      onDelete?.call();
    case null:
      break;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    // Dark fills carry white type; the yellow-family fills carry black.
    final textColor = color == AppColors.yellow
        ? AppColors.black
        : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: layout.inset(14),
          vertical: layout.gap(13),
        ),
        decoration: AppTheme.brutalBox(context, color: color),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: layout.inset(18)),
            SizedBox(width: layout.inset(10)),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: textColor,
                  fontSize: layout.font(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
