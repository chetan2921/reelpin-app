import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/core/design/app_layout.dart';
import 'package:reelpin/core/design/app_theme.dart';
part 'onboarding_partials.dart';

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
      title: 'KEEP THE POSTS, REELS, SHORTS, AND VIDEOS YOU WANT TO TRY',
      body:
          'SHARE FROM INSTAGRAM, YOUTUBE, OR X. SAVE THE PLACE, PLAN, OR FIND.',
      accent: AppTheme.yellow,
      icon: Icons.bookmark_added_outlined,
      bullet: '',
      highlights: ['SPOTS', 'PLACES TO GO', 'THINGS TO BUY'],
      platforms: [
        _OnboardingPlatform('assets/images/instagram.png', 'INSTAGRAM'),
        _OnboardingPlatform('assets/images/youtube.png', 'YOUTUBE'),
        _OnboardingPlatform('assets/images/twitter.png', 'X'),
      ],
    ),
    _OnboardingStep(
      label: 'FIND IT FAST',
      title: 'COME BACK TO THE GOOD PART IN SECONDS',
      body:
          'OPEN A SAVED REEL LATER AND GET THE PART YOU CARE ABOUT WITHOUT SCRUBBING THROUGH THE WHOLE VIDEO AGAIN.',
      accent: AppTheme.hotPink,
      icon: Icons.auto_awesome,
      bullet: 'LESS REWATCHING, MORE USING',
      highlights: ['IDEAS', 'TIPS', 'WHY YOU SAVED IT'],
    ),
    _OnboardingStep(
      label: 'USE IT OUTSIDE THE APP',
      title: 'SEE CLEARLY NAMED PLACES ON YOUR MAP',
      body:
          'WHEN A REEL CALLS OUT A PLACE BY NAME, REELPIN DROPS IT ON YOUR MAP SO YOU CAN ACTUALLY GO THERE LATER.',
      accent: AppTheme.blue,
      icon: Icons.map,
      bullet: 'SAVE NOW, USE IT WHEN YOU ARE OUT',
      highlights: ['TRIPS', 'LOCAL SAVES', 'PLANS THAT STICK'],
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
          padding: layout.pagePadding(horizontal: 20, top: 18, bottom: 30),
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
                'SAVE INSTAGRAM, YOUTUBE, AND X FINDS INTO PLANS YOU CAN USE.',
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
              SizedBox(height: layout.gap(10)),
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
                              if (step.platforms.isEmpty) ...[
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
                              ] else ...[
                                for (
                                  var i = 0;
                                  i < step.platforms.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: layout.inset(6),
                                      ),
                                      child: Text(
                                        '+',
                                        style: GoogleFonts.spaceMono(
                                          color: AppTheme.fg(context),
                                          fontSize: layout.font(12),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  Semantics(
                                    label:
                                        '${step.platforms[i].label} source platform',
                                    image: true,
                                    child: ExcludeSemantics(
                                      child: Image.asset(
                                        step.platforms[i].assetPath,
                                        width: layout.inset(22),
                                        height: layout.inset(22),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: layout.inset(4)),
                                  Text(
                                    step.platforms[i].label,
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
                                ],
                                SizedBox(width: layout.inset(10)),
                              ],
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
              SizedBox(height: layout.gap(10)),
              GestureDetector(
                onTap: _next,
                child: SizedBox(
                  width: double.infinity,
                  height: layout.gap(60),
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
                  offset: Offset(0, layout.gap(8)),
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
