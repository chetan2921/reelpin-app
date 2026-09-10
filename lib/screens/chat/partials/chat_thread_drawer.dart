import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';

class ChatThreadDrawer extends StatelessWidget {
  const ChatThreadDrawer({
    super.key,
    required this.threads,
    required this.onOpen,
    required this.onNewChat,
  });

  final List<ChatThread> threads;
  final ValueChanged<String> onOpen;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bg(context),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'YOUR CHATS',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onNewChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        border: Border.all(color: AppColors.black),
                      ),
                      child: Text(
                        '+ NEW',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: threads.isEmpty
                  ? Center(
                      child: Text(
                        'NO CHATS YET',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: threads.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.fg(context)),
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        return ListTile(
                          onTap: () => onOpen(thread.id),
                          title: Text(
                            thread.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.fg(context),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
