import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';

part 'partials/how_to_step.dart';
part 'partials/how_to_stage.dart';

/// Tap-through walkthrough of the share flow. The user advances by tapping the
/// highlighted control in each screenshot — the same one they will tap for real
/// in the source app — so the guide rehearses the gesture instead of describing
/// it.
///
/// Android and iOS have their own captures and their own wording, because the
/// two share sheets diverge after the first tap. The captures happen to show
/// Instagram, but the copy stays app-agnostic: the point is the mechanism
/// rather than any one platform.
///
/// Shown once automatically after a user's first sign-in, and available
/// afterwards from Profile.
class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key, this.isFirstRun = false});

  /// First-run presentation offers SKIP; the Profile replay offers a close
  /// button and leaves the "seen" flag alone.
  final bool isFirstRun;

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  static const _androidSteps = [
    _HowToStep(
      assetPath: 'assets/images/guide/android_step_1.png',
      label: 'STEP 1',
      title: 'TAP SHARE IN ANY APP',
      body:
          'OPEN WHAT YOU WANT TO KEEP AND TAP ITS SHARE BUTTON. INSTAGRAM IS '
          'SHOWN HERE — THE STEPS ARE THE SAME ANYWHERE ELSE.',
      accent: AppColors.yellow,
      hotspotX: 0.9267,
      hotspotY: 0.6519,
      hotspotWidth: 0.1441,
      hotspotHeight: 0.0712,
      aspectRatio: _kGuideAspectRatio,
    ),
    _HowToStep(
      assetPath: 'assets/images/guide/android_step_2.png',
      label: 'STEP 2',
      title: 'TAP SHARE AGAIN',
      body:
          'SOME APPS OPEN THEIR OWN MENU FIRST. TAP SHARE THERE TO REACH THE '
          'ANDROID SHARE SHEET.',
      accent: AppColors.hotPink,
      hotspotX: 0.3093,
      hotspotY: 0.8953,
      hotspotWidth: 0.1798,
      hotspotHeight: 0.0881,
      aspectRatio: _kGuideAspectRatio,
    ),
    _HowToStep(
      assetPath: 'assets/images/guide/android_step_3.png',
      label: 'STEP 3',
      title: 'TAP MORE',
      body: 'ANDROID SUGGESTS A FEW APPS FIRST. TAP MORE TO SEE THE FULL LIST.',
      accent: AppColors.blue,
      hotspotX: 0.8393,
      hotspotY: 0.9194,
      hotspotWidth: 0.2474,
      hotspotHeight: 0.1212,
      aspectRatio: _kGuideAspectRatio,
    ),
    _HowToStep(
      assetPath: 'assets/images/guide/android_step_4.png',
      label: 'STEP 4',
      title: 'PICK REELPIN',
      body:
          'THE LAST STEP IS THE SAME FROM EVERY APP. WE SAVE IT AND PROCESS IT '
          'IN THE BACKGROUND.',
      accent: AppColors.neonGreen,
      hotspotX: 0.5931,
      hotspotY: 0.1691,
      hotspotWidth: 0.2730,
      hotspotHeight: 0.1331,
      aspectRatio: _kGuideAspectRatio,
    ),
  ];

  static const _iosSteps = [
    _HowToStep(
      assetPath: 'assets/images/guide/ios_step_1.png',
      label: 'STEP 1',
      title: 'TAP SHARE IN ANY APP',
      body:
          'OPEN WHAT YOU WANT TO KEEP AND TAP ITS SHARE BUTTON. INSTAGRAM IS '
          'SHOWN HERE — THE STEPS ARE THE SAME ANYWHERE ELSE.',
      accent: AppColors.yellow,
      hotspotX: 0.9158,
      hotspotY: 0.7322,
      hotspotWidth: 0.1658,
      hotspotHeight: 0.0819,
      aspectRatio: _kGuideAspectRatio,
    ),
    _HowToStep(
      assetPath: 'assets/images/guide/ios_step_2.png',
      label: 'STEP 2',
      title: 'TAP SHARE TO',
      body:
          'SOME APPS OPEN THEIR OWN MENU FIRST. TAP SHARE TO REACH THE IPHONE '
          'SHARE SHEET.',
      accent: AppColors.hotPink,
      hotspotX: 0.1193,
      hotspotY: 0.9000,
      hotspotWidth: 0.1901,
      hotspotHeight: 0.0925,
      aspectRatio: _kGuideAspectRatio,
    ),
    _HowToStep(
      assetPath: 'assets/images/guide/ios_step_3.png',
      label: 'STEP 3',
      title: 'TAP MORE',
      body:
          'IPHONE SUGGESTS A FEW APPS FIRST. TAP THE THREE DOTS TO SEE THE '
          'FULL LIST.',
      accent: AppColors.blue,
      hotspotX: 0.8788,
      hotspotY: 0.2222,
      hotspotWidth: 0.2270,
      hotspotHeight: 0.1119,
      aspectRatio: _kGuideAspectRatio,
    ),
    _HowToStep(
      assetPath: 'assets/images/guide/ios_step_4.png',
      label: 'STEP 4',
      title: 'PICK REELPIN',
      body:
          'THE LAST STEP IS THE SAME FROM EVERY APP. WE SAVE IT AND PROCESS IT '
          'IN THE BACKGROUND.',
      accent: AppColors.neonGreen,
      hotspotX: 0.2136,
      hotspotY: 0.5394,
      hotspotWidth: 0.3406,
      hotspotHeight: 0.1075,
      // iOS highlights the row as a rounded rectangle, not a circle.
      hotspotCorner: 0.18,
      aspectRatio: _kGuideAspectRatio,
    ),
  ];

  /// Resolved from the theme rather than [defaultTargetPlatform] so the choice
  /// follows whatever platform the surrounding app is presenting as.
  late List<_HowToStep> _steps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _steps = Theme.of(context).platform == TargetPlatform.iOS
        ? _iosSteps
        : _androidSteps;
  }

  /// The captures are portrait phone screenshots. Letting one render wider than
  /// a phone is what makes it look stretched and soft on a tablet, so the stage
  /// stops growing past this and centres in the leftover space instead.
  static const _maxStageWidth = 430.0;

  /// Width-to-height of the window onto the capture. Fixing it means every
  /// device sees the same proportion of the screenshot (~79%) rather than a
  /// crop that varies with whatever height the chrome happens to leave. The
  /// stage shrinks to fit rather than scrolling, so the circle the guide is
  /// asking you to tap is never below the fold.
  static const _stageDisplayAspect = 0.62;

  /// Ceiling on the stage as a share of the viewport. Without it the capture
  /// claims its full natural height on a short window, forcing a scroll that
  /// puts the circle below the fold; with it the capture shrinks to fit.
  static const _stageHeightFraction = 0.72;

  int _currentStep = 0;
  bool _isReversing = false;
  bool _hasMissed = false;

  bool get _isLastStep => _currentStep == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.log(AnalyticsEvent.howToOpened));
    // Portrait phone captures have nothing sensible to show in landscape, and
    // the app locks no orientation globally.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // Empty list restores the platform default rather than pinning portrait on
    // whatever screen comes next.
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  void _advance() {
    if (_isLastStep) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isReversing = false;
      _hasMissed = false;
      _currentStep += 1;
    });
  }

  void _goBack() {
    if (_currentStep == 0) return;
    setState(() {
      _isReversing = true;
      _hasMissed = false;
      _currentStep -= 1;
    });
  }

  void _registerMiss() {
    if (_hasMissed) return;
    setState(() {
      _hasMissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final step = _steps[_currentStep];

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Padding(
          padding: layout.pagePadding(horizontal: 20, top: 8, bottom: 14),
          // The stage takes whatever the text leaves, so the column always
          // fills the screen exactly — no slack pushing the header down. Only
          // when enlarged system text outgrows the viewport does this scroll.
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: _buildContent(
                      context,
                      layout,
                      step,
                      viewportHeight: constraints.maxHeight,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLayout layout,
    _HowToStep step, {
    required double viewportHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, step),
        SizedBox(height: layout.gap(12)),
        Text(
          step.title,
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
            fontSize: layout.font(22, minFactor: 0.86, maxFactor: 1.06),
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        SizedBox(height: layout.gap(6)),
        Text(
          step.body,
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: layout.font(11.5, minFactor: 0.9, maxFactor: 1.05),
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        SizedBox(height: layout.gap(12)),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _maxStageWidth,
                maxHeight: viewportHeight * _stageHeightFraction,
              ),
              child: AspectRatio(
                aspectRatio: _stageDisplayAspect,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final begin = Offset(_isReversing ? -0.25 : 0.25, 0);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: begin,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _HowToStage(
                    key: ValueKey(step.assetPath),
                    step: step,
                    isLastStep: _isLastStep,
                    onHotspotTap: _advance,
                    onMissedTap: _registerMiss,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: layout.gap(12)),
        _buildProgress(context, step),
        SizedBox(height: layout.gap(10)),
        _buildHint(context, step),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, _HowToStep step) {
    final layout = AppLayout.of(context);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: layout.inset(10),
            vertical: layout.gap(6),
          ),
          decoration: AppTheme.brutalBox(
            context,
            color: step.accent,
            shadow: false,
          ),
          child: Text(
            '${step.label}/${_steps.length}',
            style: GoogleFonts.spaceMono(
              color: AppColors.black,
              fontSize: layout.font(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const Spacer(),
        if (_currentStep > 0)
          TextButton(
            onPressed: _goBack,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: layout.inset(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'BACK',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: layout.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SizedBox(width: layout.inset(8)),
        if (widget.isFirstRun)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: layout.inset(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'SKIP',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: layout.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, color: AppColors.fg(context)),
          ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context, _HowToStep step) {
    final layout = AppLayout.of(context);

    return Row(
      children: List.generate(_steps.length, (index) {
        final isDone = index <= _currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(
              right: index == _steps.length - 1 ? 0 : layout.inset(6),
            ),
            height: layout.gap(8),
            decoration: BoxDecoration(
              color: isDone ? step.accent : AppColors.bg(context),
              border: Border.all(color: AppColors.fg(context), width: 2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHint(BuildContext context, _HowToStep step) {
    final layout = AppLayout.of(context);
    final text = _hasMissed
        ? 'TAP INSIDE THE HIGHLIGHTED CIRCLE'
        : _isLastStep
        ? 'TAP REELPIN TO FINISH'
        : 'TAP THE CIRCLE TO CONTINUE';

    return Row(
      children: [
        Container(
          width: layout.inset(10),
          height: layout.inset(10),
          decoration: BoxDecoration(
            color: step.accent,
            border: Border.all(color: AppColors.fg(context), width: 2),
          ),
        ),
        SizedBox(width: layout.inset(10)),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.spaceMono(
              color: _hasMissed
                  ? AppColors.fg(context)
                  : AppColors.textSec(context),
              fontSize: layout.font(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    );
  }
}
