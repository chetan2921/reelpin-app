part of '../collection_detail_screen.dart';

/// The pinned sticky note above a collection's reels, carrying its note text.
/// Ported from the folders design; the pin, the crease dot and the tape strip
/// are all part of the drawing.
class _CollectionStickyNote extends StatelessWidget {
  const _CollectionStickyNote({
    required this.note,
    required this.canEdit,
    this.onEdit,
  });

  final String note;
  final bool canEdit;

  /// Tapping the paper edits the collection. Null for viewers and shared views.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final text = note.trim();
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: layout.gap(140),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: layout.inset(14),
              right: layout.inset(6),
              top: layout.gap(18),
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.black.withAlpha(70),
                  border: Border.all(color: AppColors.fg(context), width: 2),
                ),
              ),
            ),
            Positioned.fill(
              top: layout.gap(8),
              right: layout.inset(8),
              child: Transform.rotate(
                angle: -0.025,
                child: ClipPath(
                  clipper: _StickyNoteClipper(),
                  child: Container(
                    // Was 38 up top, which left an empty band under the pin
                    // before the text began.
                    padding: EdgeInsets.fromLTRB(
                      layout.inset(18),
                      layout.gap(26),
                      layout.inset(18),
                      layout.gap(14),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEA75),
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: 2,
                      ),
                      boxShadow: AppTheme.brutalShadowSmall(context),
                    ),
                    child: Text(
                      text.isEmpty
                          ? (canEdit
                                ? 'NO NOTE YET. TAP EDIT TO ADD ONE.'
                                : 'NO NOTE ON THIS COLLECTION.')
                          : text.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: AppColors.black,
                        fontSize: layout.font(13),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -layout.gap(10),
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.28,
                  child: Image.asset(
                    'assets/images/pin.png',
                    width: layout.inset(42),
                    height: layout.inset(42),
                  ),
                ),
              ),
            ),
            // The pin is rotated -0.28rad about its centre and its needle points
            // down-left, so the tip lands ~13px left and ~35px below the image
            // centre — not where an untransformed dot would sit.
            Positioned(
              top: layout.gap(32),
              left: 0,
              right: 0,
              child: Center(
                child: Transform.translate(
                  offset: Offset(-layout.inset(13), 0),
                  child: Container(
                    width: layout.inset(5),
                    height: layout.inset(5),
                    decoration: BoxDecoration(
                      color: AppColors.black.withAlpha(180),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.fg(context).withAlpha(110),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Small pencil in the note's corner so the tap target is
            // discoverable now that the header no longer carries an edit action.
            if (onEdit != null)
              Positioned(
                top: layout.gap(24),
                right: layout.inset(26),
                child: Icon(
                  Icons.edit,
                  size: layout.inset(15),
                  color: AppColors.black.withAlpha(130),
                ),
              ),
            Positioned(
              right: layout.inset(20),
              bottom: layout.gap(4),
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  width: layout.inset(48),
                  height: layout.gap(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD94A),
                    border: Border.all(
                      color: AppColors.fg(context),
                      width: 1.5,
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

class _StickyNoteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 10, size.height - 18)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height + 8,
        0,
        size.height - 8,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
