part of '../onboarding_screen.dart';

class _OnboardingStep {
  const _OnboardingStep({
    required this.label,
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
    required this.bullet,
    required this.highlights,
    this.platforms = const [],
  });

  final String label;
  final String title;
  final String body;
  final Color accent;
  final IconData icon;
  final String bullet;
  final List<String> highlights;
  final List<SourcePlatform> platforms;
}
