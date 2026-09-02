import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';

/// Holds a reel's place in the grid while the backend is still working on it.
///
/// Carries no thumbnail or title — neither exists yet — so the wait itself is
/// the content: the card fills from the bottom like a glass under a tap, at
/// whatever pace the job actually reports.
class ProcessingReelCard extends StatefulWidget {
  const ProcessingReelCard({
    super.key,
    required this.job,
    this.isSettling = false,
  });

  final ProcessingJob job;

  /// The backend is done and only the swap for the real card is pending. The
  /// water fills the rest of the way rather than holding short of the brim.
  final bool isSettling;

  @override
  State<ProcessingReelCard> createState() => _ProcessingReelCardState();
}

class _ProcessingReelCardState extends State<ProcessingReelCard>
    with TickerProviderStateMixin {
  /// Drives the surface ripple. Runs forever and independently of progress, so
  /// the card still reads as alive between polls.
  late final AnimationController _wave;

  /// Carries the level from the last reported percentage to the newest one,
  /// so a poll that jumps 20% slides instead of snapping.
  late final AnimationController _level;
  late Animation<double> _levelAnim;

  /// Never let the water reach the brim before the job is actually done: a
  /// full card that keeps sitting there reads as stuck.
  static const _maxLevel = 0.92;
  static const _minLevel = 0.06;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _level = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _levelAnim = AlwaysStoppedAnimation(_targetLevel);
    _level.value = 1;
  }

  @override
  void didUpdateWidget(covariant ProcessingReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _targetLevel;
    final current = _levelAnim.value;
    if ((next - current).abs() < 0.001) return;
    _levelAnim = Tween<double>(begin: current, end: next).animate(
      CurvedAnimation(parent: _level, curve: Curves.easeOutCubic),
    );
    _level.forward(from: 0);
  }

  double get _targetLevel {
    if (widget.isSettling) return 1;
    final percent = widget.job.progressPercent ?? 0;
    final fraction = percent / 100;
    return fraction.clamp(_minLevel, _maxLevel).toDouble();
  }

  @override
  void dispose() {
    _wave.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg(context),
            border: Border.all(
              color: AppColors.fg(context),
              width: AppTheme.borderWidth,
            ),
            boxShadow: AppTheme.brutalShadow(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_wave, _levelAnim]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _WaterPainter(
                      level: _levelAnim.value,
                      phase: _wave.value,
                      color: AppColors.yellow,
                    ),
                  );
                },
              ),
              _buildLabel(context, layout),
            ],
          ),
        ),
        // The same pierced-paper hole and pin the finished card wears, so the
        // placeholder sits in the grid as one of them rather than beside them.
        Positioned(
          right: layout.inset(14),
          top: layout.gap(14),
          child: Container(
            width: layout.inset(5),
            height: layout.inset(5),
            decoration: const BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -layout.inset(6),
          top: -layout.gap(6),
          child: Image.asset(
            'assets/images/pin.png',
            width: layout.inset(26),
            height: layout.inset(26),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, AppLayout layout) {
    final platform = SourcePlatform.byId(widget.job.sourcePlatform);

    return Padding(
      padding: EdgeInsets.all(layout.inset(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'SAVING',
            style: GoogleFonts.spaceMono(
              color: AppColors.black,
              fontWeight: FontWeight.w700,
              fontSize: layout.font(11),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: layout.gap(2)),
          Text(
            platform?.label ?? 'TO REELPIN',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: AppColors.black.withAlpha(170),
              fontWeight: FontWeight.w700,
              fontSize: layout.font(9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the rising water and its surface.
///
/// Two sine waves of different length and speed are summed so the crest never
/// repeats on a visible cycle — one wave alone reads as a sliding ruler.
class _WaterPainter extends CustomPainter {
  const _WaterPainter({
    required this.level,
    required this.phase,
    required this.color,
  });

  final double level;
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = size.height * 0.022;
    // Leave room for the crest so a full-amplitude peak cannot poke above the
    // level the job actually reported.
    final baseline = size.height * (1 - level) + amplitude;
    final sweep = phase * 2 * math.pi;

    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseline);
    for (var x = 0.0; x <= size.width; x += 2) {
      final t = x / size.width;
      final y =
          baseline +
          math.sin(t * 2 * math.pi + sweep) * amplitude +
          math.sin(t * 5 * math.pi - sweep * 1.7) * amplitude * 0.45;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WaterPainter old) {
    return old.level != level || old.phase != phase || old.color != color;
  }
}
