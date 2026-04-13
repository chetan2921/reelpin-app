import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingStep(
      label: 'SAVE IT',
      title: 'KEEP THE REELS YOU REALLY WANT TO TRY',
      body:
          'SEND A REEL TO REELPIN AND KEEP THE FOOD SPOT, WEEKEND PLAN, OR SHOPPING FIND BEFORE IT GETS LOST.',
      accent: AppTheme.yellow,
      icon: Icons.bookmark_added_outlined,
      bullet: 'ONE SHARE AND IT IS SAVED',
      highlights: ['FOOD SPOTS', 'PLACES TO GO', 'THINGS TO BUY'],
    ),
    _OnboardingStep(
      label: 'FIND IT FAST',
      title: 'COME BACK TO THE GOOD PART IN SECONDS',
      body:
          'OPEN A SAVED REEL LATER AND GET THE PART YOU CARE ABOUT WITHOUT SCRUBBING THROUGH THE WHOLE VIDEO AGAIN.',
      accent: AppTheme.blue,
      icon: Icons.auto_awesome,
      bullet: 'LESS REWATCHING, MORE USING',
      highlights: ['SPOTS', 'TIPS', 'WHY YOU SAVED IT'],
    ),
    _OnboardingStep(
      label: 'USE IT OUTSIDE THE APP',
      title: 'SEE CLEARLY NAMED PLACES ON YOUR MAP',
      body:
          'WHEN A REEL CALLS OUT A PLACE BY NAME, REELPIN DROPS IT ON YOUR MAP SO YOU CAN ACTUALLY GO THERE LATER.',
      accent: AppTheme.hotPink,
      icon: Icons.map,
      bullet: 'SAVE NOW, USE IT WHEN YOU ARE OUT',
      highlights: ['TRIP IDEAS', 'LOCAL SAVES', 'PLANS THAT STICK'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      widget.onContinue();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _pages[_currentPage];
    final layout = AppLayout.of(context);
    final buttonTextColor = step.accent.computeLuminance() > 0.5
        ? AppTheme.black
        : AppTheme.white;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Padding(
          padding: layout.pagePadding(horizontal: 20, top: 18, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REELPIN',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(28, minFactor: 0.9, maxFactor: 1.08),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: layout.gap(14)),
              Text(
                'TURN SAVED REELS INTO PLANS YOU CAN ACTUALLY USE.',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(18, minFactor: 0.9, maxFactor: 1.08),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              SizedBox(height: layout.gap(16)),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return _OnboardingCard(
                      step: item,
                      isActive: index == _currentPage,
                    );
                  },
                ),
              ),
              SizedBox(height: layout.gap(12)),
              Row(
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(
                      right: index == _pages.length - 1 ? 0 : layout.inset(8),
                    ),
                    width: _currentPage == index
                        ? layout.inset(38)
                        : layout.inset(16),
                    height: layout.gap(10),
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? step.accent
                          : AppTheme.bg(context),
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                  ),
                ),
              ),
              SizedBox(height: layout.gap(12)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  key: ValueKey(step.bullet),
                  height: layout.gap(56),
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: layout.gap(4),
                        left: layout.inset(4),
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: AppTheme.brutalBox(
                            context,
                            color: step.accent.withAlpha(150),
                            shadow: false,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.inset(14),
                          ),
                          decoration: AppTheme.brutalCard(
                            context,
                            color: AppTheme.bg(context),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: layout.inset(10),
                                height: layout.inset(10),
                                decoration: BoxDecoration(
                                  color: step.accent,
                                  border: Border.all(
                                    color: AppTheme.fg(context),
                                    width: 2,
                                  ),
                                ),
                              ),
                              SizedBox(width: layout.inset(10)),
                              Expanded(
                                child: Text(
                                  step.bullet,
                                  style: GoogleFonts.spaceMono(
                                    color: AppTheme.fg(context),
                                    fontSize: layout.font(
                                      10.5,
                                      minFactor: 0.9,
                                      maxFactor: 1.05,
                                    ),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: layout.gap(12)),
              GestureDetector(
                onTap: _next,
                child: SizedBox(
                  width: double.infinity,
                  height: layout.gap(52),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: layout.gap(4),
                        left: layout.inset(4),
                        right: 0,
                        bottom: 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          decoration: AppTheme.brutalBox(
                            context,
                            color: step.accent.withAlpha(180),
                            shadow: false,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          decoration: AppTheme.brutalCard(
                            context,
                            color: step.accent,
                          ),
                          child: Center(
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? 'CONTINUE TO LOGIN'
                                  : 'NEXT',
                              style: GoogleFonts.spaceMono(
                                color: buttonTextColor,
                                fontSize: layout.font(14),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentPage != _pages.length - 1)
                Transform.translate(
                  offset: Offset(0, layout.gap(10)),
                  child: Center(
                    child: TextButton(
                      onPressed: widget.onContinue,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.inset(12),
                          vertical: layout.gap(6),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'SKIP',
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.textSec(context),
                          fontSize: layout.font(12),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.step, required this.isActive});

  final _OnboardingStep step;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth < 360;
        final compactHeight = constraints.maxHeight < 610;
        final heroBottom =
            (constraints.maxHeight * (compactHeight ? 0.22 : 0.245))
                .clamp(layout.gap(88), layout.gap(126))
                .toDouble();
        final railWidth = (constraints.maxWidth * (compactWidth ? 0.24 : 0.29))
            .clamp(layout.inset(88), layout.inset(126))
            .toDouble();
        final titleWidth = (constraints.maxWidth - railWidth - layout.inset(74))
            .clamp(layout.inset(150), layout.inset(238))
            .toDouble();
        final heroRightInset = layout.inset(compactWidth ? 14 : 18);
        final heroBackplateInset = layout.inset(compactWidth ? 10 : 14);
        final bodyBottom = layout.gap(compactHeight ? 18 : 24);
        final bodyRightInset = railWidth + layout.inset(compactWidth ? 10 : 14);
        final railBottom = layout.gap(compactHeight ? 38 : 44);
        final cardPadding = layout.inset(compactWidth ? 14 : 18);
        final iconBoxSize = layout.inset(compactWidth ? 42 : 48);
        final pinSize = layout.inset(compactWidth ? 18 : 20);
        final iconFrameSize = iconBoxSize + layout.inset(8);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: layout.gap(compactHeight ? 10 : 14),
              left: heroBackplateInset,
              right: 0,
              bottom: heroBottom - layout.gap(6),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                offset: isActive ? Offset.zero : const Offset(0.05, 0.03),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: isActive ? 1 : 0.76,
                  child: Container(
                    decoration: AppTheme.brutalBox(
                      context,
                      color: step.accent.withAlpha(145),
                      shadow: false,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: heroRightInset,
              bottom: heroBottom,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                offset: isActive ? Offset.zero : const Offset(-0.04, 0.02),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  scale: isActive ? 1 : 0.985,
                  child: Container(
                    decoration: BoxDecoration(
                      color: step.accent,
                      border: Border.all(color: AppTheme.black, width: 3),
                      boxShadow: AppTheme.inkShadow,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: layout.inset(10),
                                  vertical: layout.gap(6),
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  border: Border.all(
                                    color: AppTheme.black,
                                    width: 2,
                                  ),
                                  boxShadow: AppTheme.inkShadowSmall,
                                ),
                                child: Text(
                                  step.label,
                                  style: GoogleFonts.spaceMono(
                                    color: AppTheme.black,
                                    fontSize: layout.font(10),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              AnimatedScale(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                scale: isActive ? 1 : 0.92,
                                child: SizedBox(
                                  width: iconFrameSize,
                                  height: iconFrameSize,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: iconBoxSize,
                                          height: iconBoxSize,
                                          decoration: BoxDecoration(
                                            color: AppTheme.white,
                                            border: Border.all(
                                              color: AppTheme.black,
                                              width: 2,
                                            ),
                                            boxShadow: AppTheme.inkShadowSmall,
                                          ),
                                          child: Icon(
                                            step.icon,
                                            color: AppTheme.black,
                                            size: layout.inset(24),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: AnimatedRotation(
                                          duration: const Duration(
                                            milliseconds: 320,
                                          ),
                                          turns: isActive ? 0 : -0.03,
                                          child: Image.asset(
                                            'assets/images/pin.png',
                                            width: pinSize,
                                            height: pinSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: layout.gap(compactHeight ? 14 : 22)),
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            offset: isActive
                                ? Offset.zero
                                : const Offset(0, 0.08),
                            child: SizedBox(
                              width: titleWidth,
                              child: Text(
                                step.title,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.black,
                                  fontSize: layout.font(
                                    compactWidth ? 20 : 23,
                                    minFactor: 0.88,
                                    maxFactor: 1.05,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  height: 1.14,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: layout.gap(compactHeight ? 12 : 18)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.inset(10),
                              vertical: layout.gap(7),
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              border: Border.all(
                                color: AppTheme.black,
                                width: 2,
                              ),
                              boxShadow: AppTheme.inkShadowSmall,
                            ),
                            child: Text(
                              step.highlights.first,
                              style: GoogleFonts.spaceMono(
                                color: AppTheme.black,
                                fontSize: layout.font(10),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: layout.inset(18),
              right: bodyRightInset,
              bottom: bodyBottom,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                offset: isActive ? Offset.zero : const Offset(-0.05, 0.08),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: isActive ? 1 : 0.86,
                  child: Container(
                    decoration: AppTheme.brutalCard(context),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(14),
                        layout.gap(14),
                        layout.inset(14),
                        layout.gap(14),
                      ),
                      child: Text(
                        step.body,
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.fg(context),
                          fontSize: layout.font(12),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              width: railWidth,
              bottom: railBottom,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                offset: isActive ? Offset.zero : const Offset(0.1, 0.04),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  scale: isActive ? 1 : 0.95,
                  child: Container(
                    decoration: AppTheme.brutalCard(
                      context,
                      color: AppTheme.white,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(10),
                        layout.gap(10),
                        layout.inset(10),
                        layout.gap(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.inset(8),
                              vertical: layout.gap(5),
                            ),
                            decoration: BoxDecoration(
                              color: step.accent,
                              border: Border.all(
                                color: AppTheme.black,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              'LOOK FOR',
                              style: GoogleFonts.spaceMono(
                                color: step.accent.computeLuminance() > 0.5
                                    ? AppTheme.black
                                    : AppTheme.white,
                                fontSize: layout.font(9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(height: layout.gap(10)),
                          ...step.highlights
                              .skip(1)
                              .map(
                                (highlight) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: layout.gap(8),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: layout.inset(8),
                                      vertical: layout.gap(7),
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bg(context),
                                      border: Border.all(
                                        color: AppTheme.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      highlight,
                                      style: GoogleFonts.spaceMono(
                                        color: AppTheme.fg(context),
                                        fontSize: layout.font(9),
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
    required this.bullet,
    required this.highlights,
  });

  final String label;
  final String title;
  final String body;
  final Color accent;
  final IconData icon;
  final String bullet;
  final List<String> highlights;
}
