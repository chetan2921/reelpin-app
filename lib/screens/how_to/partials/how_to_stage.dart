part of '../how_to_use_screen.dart';

/// Identifies the tap target so tests can confirm it stays reachable — not
/// clipped or pushed off-stage — across device sizes.
@visibleForTesting
const howToHotspotKey = ValueKey('how_to_hotspot');

/// The framed screenshot for a single step, with the tappable hotspot pinned
/// over the highlight already baked into the image.
///
/// A 9:19.5 phone capture letterboxed inside page chrome ends up too small to
/// read, so the screenshot is drawn at full width and the visible window is
/// panned vertically to keep that step's highlight near the middle of the frame.
///
/// Forward motion is driven entirely by [onHotspotTap]; a tap anywhere else on
/// the screenshot reports a miss so the parent can surface a nudge.
class _HowToStage extends StatefulWidget {
  const _HowToStage({
    super.key,
    required this.step,
    required this.onHotspotTap,
    required this.onMissedTap,
    required this.isLastStep,
  });

  final _HowToStep step;
  final VoidCallback onHotspotTap;
  final VoidCallback onMissedTap;
  final bool isLastStep;

  @override
  State<_HowToStage> createState() => _HowToStageState();
}

class _HowToStageState extends State<_HowToStage>
    with SingleTickerProviderStateMixin {
  static const _minHotspotSide = 48.0;

  /// How far past the screenshot's own highlight the pulse travels before
  /// fading.
  static const _maxPulseScale = 1.55;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;

    return Container(
      decoration: AppTheme.brutalCard(context, color: AppColors.black),
      padding: const EdgeInsets.all(AppTheme.borderWidth),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boxWidth = constraints.maxWidth;
            final boxHeight = constraints.maxHeight;
            final imageHeight = boxWidth / step.aspectRatio;
            final overflow = imageHeight - boxHeight;

            // Slide the capture so this step's highlight sits mid-frame,
            // without ever exposing a gap above or below the artwork.
            final double topOffset = overflow <= 0
                ? (boxHeight - imageHeight) / 2
                : ((boxHeight / 2) - (step.hotspotY * imageHeight)).clamp(
                    -overflow,
                    0.0,
                  );

            // The highlight drawn into the screenshot, in on-screen pixels. The
            // pulse starts flush with it so the two read as one mark.
            final markWidth = boxWidth * step.hotspotWidth;
            final markHeight = imageHeight * step.hotspotHeight;
            final corner = math.min(markWidth, markHeight) * step.hotspotCorner;
            final centreX = boxWidth * step.hotspotX;
            final centreY = (step.hotspotY * imageHeight) + topOffset;

            final pulseWidth = markWidth * _maxPulseScale;
            final pulseHeight = markHeight * _maxPulseScale;

            // The tap target keeps its own accessibility floor, so a small
            // highlight on a narrow screen stays comfortably tappable without
            // dragging the pulse out of alignment with the artwork.
            final tapWidth = math.max(markWidth, _minHotspotSide);
            final tapHeight = math.max(markHeight, _minHotspotSide);

            return Stack(
              children: [
                // A miss anywhere on the screenshot nudges instead of
                // advancing, so the highlight stays the only way forward.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onMissedTap,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: topOffset,
                  width: boxWidth,
                  height: imageHeight,
                  child: IgnorePointer(
                    child: Image.asset(
                      step.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, _) =>
                          _buildMissingAsset(context),
                    ),
                  ),
                ),
                Positioned(
                  left: centreX - (pulseWidth / 2),
                  top: centreY - (pulseHeight / 2),
                  width: pulseWidth,
                  height: pulseHeight,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _HotspotPulsePainter(
                            progress: _pulseController.value,
                            markWidth: markWidth,
                            markHeight: markHeight,
                            corner: corner,
                            maxScale: _maxPulseScale,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  key: howToHotspotKey,
                  left: centreX - (tapWidth / 2),
                  top: centreY - (tapHeight / 2),
                  width: tapWidth,
                  height: tapHeight,
                  child: Semantics(
                    button: true,
                    label: widget.isLastStep
                        ? 'Select ReelPin to finish the guide'
                        : 'Continue to the next step',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onHotspotTap,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMissingAsset(BuildContext context) {
    final layout = AppLayout.of(context);
    return ColoredBox(
      color: AppColors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(layout.inset(20)),
          child: Text(
            'SCREENSHOT MISSING\n${widget.step.assetPath}',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              color: AppColors.white,
              fontSize: layout.font(11),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws outlines that start flush with the highlight already in the screenshot
/// and expand outward from it, so the two read as one continuous mark instead of
/// a second shape floating over the artwork.
///
/// Rounded rectangles rather than circles, because iOS highlights ReelPin's row
/// in the share sheet with a rounded rectangle while every other step uses a
/// circle — a corner radius of half the shorter side covers both.
///
/// Always yellow: it is echoing the annotation baked into the capture, so it
/// does not follow the per-step accent used by the surrounding chrome.
class _HotspotPulsePainter extends CustomPainter {
  const _HotspotPulsePainter({
    required this.progress,
    required this.markWidth,
    required this.markHeight,
    required this.corner,
    required this.maxScale,
  });

  final double progress;
  final double markWidth;
  final double markHeight;
  final double corner;
  final double maxScale;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);

    for (final offset in const [0.0, 0.5]) {
      final t = (progress + offset) % 1.0;
      final scale = 1 + (t * (maxScale - 1));
      final opacity = (1 - t).clamp(0.0, 1.0);
      if (opacity <= 0.02) continue;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centre,
            width: markWidth * scale,
            height: markHeight * scale,
          ),
          Radius.circular(corner * scale),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.yellow.withValues(alpha: opacity * 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_HotspotPulsePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.markWidth != markWidth ||
      oldDelegate.markHeight != markHeight ||
      oldDelegate.corner != corner;
}
