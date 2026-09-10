import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/chat/chat_answer_actions.dart';
import 'package:reelpin/components/chat/chat_answer_text.dart';
import 'package:reelpin/components/chat/chat_chart_block.dart';
import 'package:reelpin/components/chat/chat_places_block.dart';
import 'package:reelpin/components/chat/chat_reel_strip.dart';
import 'package:reelpin/components/chat/chat_table_block.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';

/// The assistant's side of the conversation.
///
/// Styled like the transcript box on the reel detail screen — a filled,
/// solid-bordered card — so an answer reads the same way that other
/// generated text already does elsewhere in the app.
class ChatAnswerCard extends StatelessWidget {
  const ChatAnswerCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.library,
    required this.reelCache,
    required this.onTapReel,
    required this.onSaveToCollection,
  });

  final ChatMessage message;

  /// Null when this failed message is not the thread's last message.
  /// `retryLast()` only knows how to redo the last question, so offering
  /// RETRY on an earlier failure would let it destroy a later, successful
  /// answer instead of retrying the one the user tapped.
  final VoidCallback? onRetry;
  final List<Reel> library;
  final ChatReelCache reelCache;
  final ValueChanged<Reel> onTapReel;
  final VoidCallback onSaveToCollection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedColor(context),
        border: Border.all(color: AppColors.fg(context), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.status == MessageStatus.failed
            ? [_buildFailure(context)]
            : [
                if (message.isShared) _buildSharedMarker(context),
                ...message.blocks.map((b) => _buildBlock(context, b)),
                if (message.status == MessageStatus.complete)
                  ChatAnswerActions(
                    message: message,
                    onSaveToCollection: onSaveToCollection,
                  ),
              ],
      ),
    );
  }

  /// Marks an answer somebody generated in their own private chat and then
  /// published here, so the thread does not read as if the AI was asked this
  /// in the open.
  Widget _buildSharedMarker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        'SHARED FROM A PRIVATE CHAT',
        style: GoogleFonts.spaceMono(
          color: AppColors.textTertiary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, AnswerBlock block) {
    // Exhaustive over the sealed hierarchy: a sixth block type will not
    // compile until it is handled here. Task 7 fills in the other four.
    switch (block) {
      case TextBlock(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatAnswerTextView(text: text),
        );
      case ReelRefsBlock(:final reelIds):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatReelStrip(
            reelIds: reelIds,
            library: library,
            reelCache: reelCache,
            onTapReel: onTapReel,
          ),
        );
      case PlacesBlock(:final places):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatPlacesBlockView(places: places),
        );
      case TableBlock():
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatTableBlockView(block: block),
        );
      case ChartBlock():
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatChartBlockView(block: block),
        );
    }
  }

  Widget _buildFailure(BuildContext context) {
    final onRetry = this.onRetry;
    return Row(
      children: [
        Expanded(
          child: Text(
            "That didn't go through.",
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: 12,
            ),
          ),
        ),
        if (onRetry != null)
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                border: Border.all(color: AppColors.fg(context)),
              ),
              child: Text(
                'RETRY',
                style: GoogleFonts.spaceMono(
                  color: AppColors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
