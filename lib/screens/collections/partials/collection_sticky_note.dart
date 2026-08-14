part of '../collection_detail_screen.dart';

/// The pinned sticky note above a collection's reels, carrying its note text.
/// Ported from the folders design; the pin, the crease dot and the tape strip
/// are all part of the drawing.
/// Rotation applied to the pin artwork; the hole position is solved from it.
const double _pinAngle = -0.28;

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

    // Everything about the pin scales from this one value.
    final pinSize = layout.inset(30);
    final pinTop = -layout.gap(6);
    final holeSize = layout.inset(4);
    // The needle tip sits at roughly (0.04, 0.96) of the asset, so after
    // rotating about the centre it lands at these fractions of the pin's size.
    // Solving it here keeps the hole on the point at any pin size.
    final pinTipDx = -0.315 * pinSize;
    final pinTipY = pinTop + pinSize / 2 + 0.569 * pinSize;
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
            // Pin, its hole, and the tape are all derived from `pinSize` and
            // `pinTop` below rather than hand-placed, so they stay aligned at
            // every text scale and screen density instead of only at the size
            // they were eyeballed on.
            Positioned(
              top: pinTop,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: _pinAngle,
                  child: Image.asset(
                    'assets/images/pin.png',
                    width: pinSize,
                    height: pinSize,
                  ),
                ),
              ),
            ),
            Positioned(
              top: pinTipY - holeSize / 2,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.translate(
                  offset: Offset(pinTipDx, 0),
                  child: Container(
                    width: holeSize,
                    height: holeSize,
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
            // The tape strip doubles as the edit control for owners and
            // editors. Viewers still see the tape, just without the label, so
            // the artwork is unchanged for people who cannot act on it.
            Positioned(
              right: layout.inset(18),
              bottom: layout.gap(6),
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  // The strip keeps the size it has always had; the label is
                  // scaled down to fit it rather than the other way round, so
                  // a large text scale cannot grow the artwork.
                  width: layout.inset(48),
                  height: layout.gap(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD94A),
                    border: Border.all(
                      color: AppColors.fg(context),
                      width: 1.5,
                    ),
                  ),
                  child: onEdit == null
                      ? null
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: layout.inset(9),
                                color: AppColors.black,
                              ),
                              SizedBox(width: layout.inset(3)),
                              Text(
                                'EDIT',
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.black,
                                  fontSize: layout.font(10),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
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
