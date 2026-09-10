import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/chat/chat_answer_card.dart';
import 'package:reelpin/components/chat/chat_question_bubble.dart';
import 'package:reelpin/components/chat/chat_thinking_stages.dart';
import 'package:reelpin/components/collections/share_to_collection_chat.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/components/chat/chat_composer.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';
import 'package:reelpin/view_models/collection_chat_view_model.dart';

/// A collection's shared AI thread: everyone with access reads it, owners and
/// editors ask into it.
///
/// Built from the private chat's own components — the same bubbles, answer
/// cards and composer — so an answer here is exactly as rich as one there.
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
              onSend: (text) => unawaited(viewModel.ask(text)),
              enabled: !viewModel.isAsking,
            ),
          ),
      ],
    );
  }

  Widget _thread(
    CollectionChatViewModel viewModel,
    List<ChatMessage> messages,
  ) {
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
          // Passes the answer on to another collection's chat; the one it is
          // already in is left out of the picker.
          onSaveToCollection: () => unawaited(
            shareToCollectionChat(
              context,
              ref,
              messages: messages,
              index: messages.length - 1 - index,
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
