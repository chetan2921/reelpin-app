part of '../onboarding_screen.dart';

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
            (constraints.maxHeight * (compactHeight ? 0.28 : 0.31))
                .clamp(layout.gap(118), layout.gap(172))
                .toDouble();
        final railWidth = (constraints.maxWidth * (compactWidth ? 0.24 : 0.29))
            .clamp(layout.inset(88), layout.inset(126))
            .toDouble();
        final titleWidth = (constraints.maxWidth - railWidth - layout.inset(74))
            .clamp(layout.inset(150), layout.inset(238))
            .toDouble();
        final heroRightInset = layout.inset(compactWidth ? 14 : 18);
        final heroBackplateInset = layout.inset(compactWidth ? 10 : 14);
        final bodyBottom = layout.gap(compactHeight ? 70 : 82);
        final bodyRightInset = railWidth + layout.inset(compactWidth ? 10 : 14);
        final railBottom = layout.gap(compactHeight ? 94 : 106);
        final cardPadding = layout.inset(compactWidth ? 14 : 18);
        final iconBoxSize = layout.inset(compactWidth ? 42 : 48);
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
                      border: Border.all(color: AppColors.black, width: 3),
                      boxShadow: AppTheme.inkShadow,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
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
                                      color: AppColors.white,
                                      border: Border.all(
                                        color: AppColors.black,
                                        width: 2,
                                      ),
                                      boxShadow: AppTheme.inkShadowSmall,
                                    ),
                                    child: Text(
                                      step.label,
                                      style: GoogleFonts.spaceMono(
                                        color: AppColors.black,
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
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Container(
                                          width: iconBoxSize,
                                          height: iconBoxSize,
                                          decoration: BoxDecoration(
                                            color: AppColors.white,
                                            border: Border.all(
                                              color: AppColors.black,
                                              width: 2,
                                            ),
                                            boxShadow: AppTheme.inkShadowSmall,
                                          ),
                                          child: Icon(
                                            step.icon,
                                            color: AppColors.black,
                                            size: layout.inset(24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: layout.gap(compactHeight ? 14 : 22),
                              ),
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
                                      color: AppColors.black,
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
                            ],
                          ),
                        ),
                        // Positioned(
                        //   top: layout.gap(150),
                        //   right: layout.inset(50),
                        //   child: AnimatedRotation(
                        //     duration: const Duration(milliseconds: 320),
                        //     turns: isActive ? 0 : -0.03,
                        //     child: Image.asset(
                        //       'assets/images/pin.png',
                        //       width: pinSize,
                        //       height: pinSize,
                        //     ),
                        //   ),
                        // ),
                      ],
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
                          color: AppColors.fg(context),
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
                      color: AppColors.white,
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
                                color: AppColors.black,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              'LOOK FOR',
                              style: GoogleFonts.spaceMono(
                                color: step.accent.computeLuminance() > 0.5
                                    ? AppColors.black
                                    : AppColors.white,
                                fontSize: layout.font(10),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(height: layout.gap(10)),
                          ...step.highlights.map(
                            (highlight) => Padding(
                              padding: EdgeInsets.only(bottom: layout.gap(8)),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: layout.inset(8),
                                  vertical: layout.gap(7),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bg(context),
                                  border: Border.all(
                                    color: AppColors.black,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  highlight,
                                  style: GoogleFonts.spaceMono(
                                    color: AppColors.fg(context),
                                    fontSize: layout.font(10),
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
