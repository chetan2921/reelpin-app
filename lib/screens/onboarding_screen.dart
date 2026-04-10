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
      label: 'STEP 01',
      title: 'SAVE REELS YOU ACTUALLY WANT TO COME BACK TO',
      body:
          'SEND A REEL TO REELPIN AND KEEP THE BEST IDEAS, SPOTS, TIPS, AND INSPIRATION IN ONE EASY PLACE.',
      accent: AppTheme.yellow,
      icon: Icons.ios_share,
      bullet: 'SAVE IDEAS BEFORE THEY DISAPPEAR',
    ),
    _OnboardingStep(
      label: 'STEP 02',
      title: 'FIND THE GOOD PARTS FASTER',
      body:
          'REELPIN HELPS YOU PULL OUT WHAT MATTERS SO YOU CAN FIND PLACES, TIPS, AND RECOMMENDATIONS WITHOUT REWATCHING EVERYTHING.',
      accent: AppTheme.blue,
      icon: Icons.auto_awesome,
      bullet: 'LESS SCROLLING. MORE KEEPING.',
    ),
    _OnboardingStep(
      label: 'STEP 03',
      title: 'SEARCH IT. MAP IT. USE IT.',
      body:
          'BUILD YOUR OWN REEL ARCHIVE FOR FOOD SPOTS, TRAVEL PLANS, FITNESS IDEAS, SHOPPING FINDS, AND MORE.',
      accent: AppTheme.orange,
      icon: Icons.map,
      bullet: 'YOUR FAVORITES, FINALLY ORGANIZED',
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

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'REELPIN',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.hotPink,
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                    child: Text(
                      'HOW IT WORKS',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'KEEP THE REELS THAT INSPIRE YOU CLOSE.',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
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
                    return _OnboardingCard(step: item);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(
                      right: index == _pages.length - 1 ? 0 : 8,
                    ),
                    width: _currentPage == index ? 40 : 16,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? step.accent
                          : AppTheme.bg(context),
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen,
                  border: Border.all(color: AppTheme.black, width: 3),
                  boxShadow: AppTheme.inkShadow,
                ),
                child: Text(
                  step.bullet,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _next,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    border: Border.all(color: AppTheme.black, width: 3),
                    boxShadow: AppTheme.inkShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'CONTINUE TO LOGIN'
                            : 'NEXT',
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_currentPage != _pages.length - 1)
                Center(
                  child: TextButton(
                    onPressed: widget.onContinue,
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.textSec(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
  const _OnboardingCard({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: step.accent,
              border: Border.all(color: AppTheme.black, width: 3),
              boxShadow: AppTheme.inkShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.black, width: 2),
                    ),
                    child: Icon(step.icon, color: AppTheme.black, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    step.label,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        step.title,
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            decoration: AppTheme.brutalCard(context),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                step.body,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
      ],
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
  });

  final String label;
  final String title;
  final String body;
  final Color accent;
  final IconData icon;
  final String bullet;
}
