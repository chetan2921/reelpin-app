import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';

/// Folder-shaped collection tile: a tab, a body in a rotating accent colour,
/// the pinned sticky note when the collection has one, and a reel count on the
/// paper peeking out behind. Ported from the folders design.
///
/// Shared by the SAVED grid and the add-to-collection picker so the artwork
/// only exists once. [compact] drops the note and count for tight grids.
class CollectionFolderTile extends StatelessWidget {
  const CollectionFolderTile({
    super.key,
    required this.collection,
    required this.index,
    required this.onTap,
    this.compact = false,
    this.overlay,
  });

  final CollectionSummary collection;

  /// Drives the accent colour so a grid cycles through the palette.
  final int index;
  final VoidCallback? onTap;
  final bool compact;

  /// Drawn over the folder body — used by the picker for its added state.
  final Widget? overlay;

  static const _accents = [
    Color(0xFF7DB5FF),
    AppColors.yellow,
    Color(0xFFFF6B6B),
    AppColors.cyan,
    AppColors.neonGreen,
  ];

  static Color accentFor(int index) => _accents[index % _accents.length];

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(index);
    final note = collection.description.trim();
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Shadow slab behind the folder.
          Positioned(
            top: 14,
            left: 8,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.fg(context), width: 2),
              ),
            ),
          ),
          // The sheet of paper poking above the folder tab.
          Positioned(
            top: 5,
            left: 16,
            right: 14,
            height: 34,
            child: Transform.rotate(
              angle: -0.025,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg(context),
                  border: Border.all(color: AppColors.fg(context), width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 6,
            right: 6,
            bottom: 4,
            child: _FolderShape(
              name: collection.name,
              accent: accent,
              note: compact ? '' : note,
            ),
          ),
          if (!compact)
            Positioned(
              top: 7,
              right: 23,
              child: _CountLabel(count: collection.itemCount),
            ),
          if (collection.hasLink && !compact)
            Positioned(
              top: 22,
              right: 12,
              child: _SharedBadge(isOwner: collection.isOwner),
            ),
          if (overlay != null)
            Positioned(top: 16, left: 6, right: 6, bottom: 4, child: overlay!),
        ],
      ),
    );
  }
}

class _FolderShape extends StatelessWidget {
  const _FolderShape({
    required this.name,
    required this.accent,
    required this.note,
  });

  final String name;
  final Color accent;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Folder tab.
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: 66,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              border: Border.all(color: AppColors.fg(context), width: 2),
            ),
          ),
        ),
        Positioned.fill(
          top: 15,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
            decoration: BoxDecoration(
              color: accent,
              border: Border.all(color: AppColors.fg(context), width: 2),
              boxShadow: AppTheme.brutalShadowSmall(context),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                name.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: AppColors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (note.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 9,
            child: _PinnedNote(note: note),
          ),
      ],
    );
  }
}

/// The small sticky note clipped to the folder body.
class _PinnedNote extends StatelessWidget {
  const _PinnedNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.025,
      child: SizedBox(
        height: 54,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: 3,
              top: 5,
              bottom: 0,
              child: ClipPath(
                clipper: _NoteClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.black.withAlpha(70),
                    border: Border.all(color: AppColors.fg(context), width: 1),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: 3,
              bottom: 2,
              child: ClipPath(
                clipper: _NoteClipper(),
                child: Container(
                  // Tight padding and a centred child: the note is small enough
                  // that generous insets pushed a wrapped second line into the
                  // bottom-right corner instead of reading as a block of text.
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEA75),
                    border: Border.all(
                      color: AppColors.fg(context),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    note.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      // Deliberate exception to the app's 10pt floor. This note
                      // is ~120px wide inside a grid tile, and 10pt crowded it
                      // to the edges. Do not raise it without shrinking the
                      // surrounding folder artwork too.
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 0,
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  width: 30,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD94A),
                    border: Border.all(
                      color: AppColors.fg(context),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.025,
      child: Text(
        '$count PIN${count == 1 ? '' : 'S'}',
        style: GoogleFonts.spaceMono(
          color: AppColors.fg(context),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Marks a collection that is link-shared, or one shared with you by someone
/// else. No folders equivalent — collections-only.
class _SharedBadge extends StatelessWidget {
  const _SharedBadge({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        border: Border.all(color: AppColors.fg(context), width: 1.5),
      ),
      child: Icon(
        isOwner ? Icons.link : Icons.group,
        size: 10,
        color: AppColors.fg(context),
      ),
    );
  }
}

class _NoteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 6, size.height - 10)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height + 5,
        0,
        size.height - 5,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
