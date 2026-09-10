import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';

/// Shows how the answer is being built. The matched-category line is the point
/// of this widget: it is where the user sees the app went to the right part of
/// their library, which a spinner cannot convey.
class ChatThinkingStages extends StatelessWidget {
  const ChatThinkingStages({super.key, required this.stages});

  final List<ThinkingStage> stages;

  /// One palette colour per position, so a completed run reads as progress
  /// rather than as a row of identical ticks.
  static const _tickColors = [
    AppColors.blue,
    AppColors.neonGreen,
    AppColors.orange,
    AppColors.hotPink,
  ];

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      // Send and the first stage event are separated by a real network round
      // trip against a live backend. Without this, that gap renders as an
      // empty Column — zero height — and the message list jumps when the
      // first stage finally lands. This row holds the same space a real one
      // would, so nothing shifts when it is swapped for the first stage.
      return _buildRow(context, label: 'THINKING', isPending: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(stages.length, (index) {
        final stage = stages[index];
        final isPending = stage.state == ThinkingStageState.pending;
        final color = _tickColors[index % _tickColors.length];

        return _buildRow(
          context,
          label: stage.label,
          isPending: isPending,
          tickColor: isPending ? null : color,
          done: stage.state == ThinkingStageState.done,
        );
      }),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required bool isPending,
    Color? tickColor,
    bool done = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: tickColor,
              border: Border.all(
                color: isPending
                    ? AppColors.textTertiary
                    : AppColors.fg(context),
              ),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check, size: 9, color: AppColors.black)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceMono(
                color: isPending
                    ? AppColors.textTertiary
                    : AppColors.fg(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
