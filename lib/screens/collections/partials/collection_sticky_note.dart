part of '../collection_detail_screen.dart';

/// The pinned sticky note above a collection's reels, carrying its note text.
/// Ported from the folders design; the pin, the crease dot and the tape strip
/// are all part of the drawing.
class _CollectionStickyNote extends StatelessWidget {
  const _CollectionStickyNote({required this.note, required this.canEdit});

  final String note;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final text = note.trim();
    return SizedBox(
      height: layout.gap(170),
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
                  padding: EdgeInsets.fromLTRB(
                    layout.inset(22),
                    layout.gap(38),
                    layout.inset(22),
                    layout.gap(18),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEA75),
                    border: Border.all(color: AppColors.fg(context), width: 2),
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
          Positioned(
            top: layout.gap(27),
            left: 0,
            right: 0,
            child: Center(
              child: Transform.translate(
                offset: Offset(-layout.inset(2), 0),
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
                  border: Border.all(color: AppColors.fg(context), width: 1.5),
                ),
              ),
            ),
          ),
        ],
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
