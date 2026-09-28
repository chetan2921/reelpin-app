import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';

/// The model's own picks, beyond what the user saved, matched to their
/// taste. One card per suggestion: its title, a small `kind` tag, and the
/// one-line reason it fits — never a reel, so never a "from your saves" card.
class ChatSuggestionsBlockView extends StatelessWidget {
  const ChatSuggestionsBlockView({super.key, required this.block});

  final SuggestionsBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.title,
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in block.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SuggestionCard(item: item),
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item});

  final Suggestion item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        border: Border.all(color: AppColors.fg(context)),
        boxShadow: AppTheme.brutalShadowSmall(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.kind.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  color: AppColors.yellow,
                  child: Text(
                    item.kind.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (item.why.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.why,
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
