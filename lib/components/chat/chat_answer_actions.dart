import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/services/sharing/reel_share_service.dart';

/// Flattens an answer for the clipboard and the share sheet.
///
/// Reel references are skipped rather than rendered as ids: pasting "r1, r2"
/// into a message is worse than pasting nothing.
String answerPlainText(ChatMessage message) {
  final buffer = StringBuffer();
  for (final block in message.blocks) {
    switch (block) {
      case TextBlock(:final text):
        buffer.writeln(text);
      case TableBlock(:final columns, :final rows):
        buffer.writeln(columns.join('\t'));
        for (final row in rows) {
          buffer.writeln(row.join('\t'));
        }
      case PlacesBlock(:final places):
        for (final place in places) {
          buffer.writeln('• ${place.name}');
        }
      case ChartBlock(:final title, :final bars):
        buffer.writeln(title);
        for (final bar in bars) {
          buffer.writeln('${bar.label}: ${bar.value.toStringAsFixed(0)}');
        }
      case ReelRefsBlock():
        break;
    }
  }
  return buffer.toString().trim();
}

/// The action row under a completed answer: copy, share, save-to-collection,
/// plus disabled placeholders for where this is going next.
class ChatAnswerActions extends StatelessWidget {
  const ChatAnswerActions({
    super.key,
    required this.message,
    required this.onSaveToCollection,
  });

  final ChatMessage message;

  /// Puts this answer into a collection's chat.
  final VoidCallback onSaveToCollection;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 9),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.textTertiary.withAlpha(90)),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _chip(
            context,
            label: '⧉ COPY',
            colour: AppColors.cyan,
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: answerPlainText(message)),
              );
            },
          ),
          _chip(
            context,
            label: '↗ SHARE',
            colour: AppColors.lime,
            onTap: () => ReelShareService.shareText(
              text: answerPlainText(message),
              subject: 'From ReelPin',
            ),
          ),
          // Offered on every answer, reels cited or not: what lands in the
          // collection's chat is the answer itself.
          _chip(
            context,
            label: '+ COLLECTION',
            colour: AppColors.yellow,
            onTap: onSaveToCollection,
          ),
          _chip(context, label: 'NOTION', colour: null, onTap: null),
          _chip(context, label: 'CALENDAR', colour: null, onTap: null),
          _chip(context, label: 'SLACK', colour: null, onTap: null),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color? colour,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colour,
          border: Border.all(
            color: disabled ? AppColors.textTertiary : AppColors.fg(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            color: disabled ? AppColors.textTertiary : AppColors.black,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
