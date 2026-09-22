import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/chat/chat_answer_card.dart';
import 'package:reelpin/components/chat/chat_attachment_sheet.dart';
import 'package:reelpin/components/chat/chat_composer.dart';
import 'package:reelpin/components/chat/chat_question_bubble.dart';
import 'package:reelpin/components/chat/chat_thinking_stages.dart';
import 'package:reelpin/components/collections/share_to_collection_chat.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';
import 'package:reelpin/view_models/collection_chat_view_model.dart';

/// The open conversation of a collection's chat, and the composer to ask into
/// it. The ASK screen puts the sidebar and header around it.
///
/// Built from the private chat's own components — the same bubbles, answer
/// cards, composer and attachment sheet — so an answer here is exactly as rich
/// as one there.
class CollectionChatPanel extends ConsumerStatefulWidget {
  const CollectionChatPanel({
    super.key,
    required this.collectionId,
    required this.canEdit,
  });

  final String collectionId;

  /// Owner or editor. A viewer reads the thread and gets no composer, the same
  /// permission tier that already governs adding reels.
  final bool canEdit;

  @override
  ConsumerState<CollectionChatPanel> createState() =>
      _CollectionChatPanelState();
}

class _CollectionChatPanelState extends ConsumerState<CollectionChatPanel> {
  late final ChatReelCache _reelCache = ChatReelCache(
    (reelId) => ref.read(reelRepositoryProvider).getReel(reelId),
  );
  final List<ChatAttachment> _pending = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = ref.read(
        collectionChatViewModelProvider(widget.collectionId),
      );
      unawaited(
        viewModel.load().then((_) {
          // The panel may have gone while the first load was in flight, and
          // with it the view model; a timer started now would never stop.
          if (mounted) viewModel.startPolling();
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(
      collectionChatViewModelProvider(widget.collectionId),
    );
    final messages = viewModel.messages;

    final Widget body;
    if (messages.isNotEmpty) {
      body = _thread(viewModel, messages);
    } else if (!viewModel.hasLoaded || viewModel.isLoading) {
      body = Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.fg(context),
          ),
        ),
      );
    } else if (viewModel.error != null) {
      body = _failed(context, viewModel);
    } else {
      body = _empty(context);
    }

    return Column(
      children: [
        Expanded(child: body),
        if (widget.canEdit)
          SafeArea(
            top: false,
            child: ChatComposer(
              enabled: !viewModel.isAsking,
              pending: _pending,
              onRemoveAttachment: (i) => setState(() => _pending.removeAt(i)),
              onAttach: () async {
                final attachment = await showChatAttachmentSheet(
                  context,
                  library: ref.read(reelRepositoryProvider).cachedReels,
                );
                if (attachment == null || !mounted) return;
                setState(() => _pending.add(attachment));
              },
              onSend: (text) {
                final attachments = List<ChatAttachment>.from(_pending);
                setState(_pending.clear);
                unawaited(viewModel.ask(text, attachments: attachments));
              },
            ),
          ),
      ],
    );
  }

  Widget _thread(
    CollectionChatViewModel viewModel,
    List<ChatMessage> rawMessages,
  ) {
    // A shared answer's paired "question" row holds the private question that
    // produced it — asked in someone's own chat, not here — so it never gets
    // its own bubble. Only who shared the answer is shown, on the answer
    // itself, resolved from that same row before it's filtered out.
    final sharedByName = <String, String>{};
    for (var i = 0; i < rawMessages.length - 1; i++) {
      final question = rawMessages[i];
      final answer = rawMessages[i + 1];
      if (question.role == MessageRole.user &&
          question.isShared &&
          answer.role == MessageRole.assistant &&
          answer.isShared &&
          question.authorName.trim().isNotEmpty) {
        sharedByName[answer.id] = question.authorName;
      }
    }
    final messages = rawMessages
        .where((m) => !(m.role == MessageRole.user && m.isShared))
        .toList();

    // Reversed, so the thread opens on its newest entry and stays pinned
    // there as the poll appends — the end of a shared log is what changed.
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        if (message.role == MessageRole.user) {
          return ChatQuestionBubble(message: message);
        }
        if (message.status == MessageStatus.sending) {
          return ChatThinkingStages(stages: viewModel.stages);
        }
        return ChatAnswerCard(
          message: message,
          // No retry here: re-asking in a shared thread puts a second attempt
          // in front of everyone, so it should be a deliberate new question.
          onRetry: null,
          library: ref.read(reelRepositoryProvider).cachedReels,
          reelCache: _reelCache,
          onTapReel: (reel) =>
              Navigator.of(context).push(reelDetailRoute(reel)),
          sharedByName: sharedByName[message.id],
          // Passes the answer on to another collection's chat; the one it is
          // already in is left out of the picker.
          onSaveToCollection: () => unawaited(
            shareToCollectionChat(
              context,
              ref,
              blocks: message.blocks,
              excludeCollectionId: widget.collectionId,
            ),
          ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          widget.canEdit
              ? 'NOTHING HERE YET.\nASK SOMETHING ABOUT THIS COLLECTION —\n'
                    'EVERYONE IN IT WILL SEE THE ANSWER.'
              : 'NOTHING HERE YET.\nEDITORS CAN ASK QUESTIONS ABOUT\n'
                    'THIS COLLECTION HERE.',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            color: AppColors.textTertiary,
            fontSize: 10,
            height: 1.9,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _failed(BuildContext context, CollectionChatViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              viewModel.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => unawaited(viewModel.load()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
        ),
      ),
    );
  }
}
