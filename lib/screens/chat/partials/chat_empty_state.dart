import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.savedCount,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final int savedCount;

  static const _spineColors = [
    AppColors.blue,
    AppColors.orange,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    // Anchored near the top with room to breathe, not dead-centered — with
    // the pin icon gone and only three short cards below it, centering left
    // the same amount of blank space above and below and read as sparse.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 48, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ASK YOUR SAVES',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            savedCount > 0
                ? 'Ask anything about the $savedCount things you have saved.'
                : 'Save something first, then ask me anything about it.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: 11.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          ...List.generate(suggestions.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onSuggestionTap(suggestions[index]),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg(context),
                    border: Border.all(color: AppColors.fg(context)),
                    boxShadow: AppTheme.brutalShadowSmall(context),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          color: _spineColors[index % _spineColors.length],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 11,
                            ),
                            child: Text(
                              suggestions[index],
                              style: GoogleFonts.spaceMono(
                                color: AppColors.fg(context),
                                fontSize: 11.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
