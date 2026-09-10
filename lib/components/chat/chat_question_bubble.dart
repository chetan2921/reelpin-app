import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';

/// The user's own words: solid yellow, bordered, shadowed — the same treatment
/// every other piece of user content gets.
class ChatQuestionBubble extends StatelessWidget {
  const ChatQuestionBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        // A cap, not a fixed width — a short message like "hi" shrinks to
        // fit instead of stretching to fill it.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.yellow,
            border: Border.all(color: AppColors.black),
            boxShadow: AppTheme.inkShadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only a shared thread has more than one author; in the private
              // chat this is empty and the bubble looks exactly as it did.
              if (message.authorName.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    message.authorName.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              if (message.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: message.attachments
                        .map(
                          (attachment) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              border: Border.all(color: AppColors.black),
                            ),
                            child: Text(
                              '${attachment.kind.label} · ${attachment.displayName}'
                                  .toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: AppColors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Text(
                message.text,
                style: GoogleFonts.spaceMono(
                  color: AppColors.black,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
