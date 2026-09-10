import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/chat/chat_answer_card.dart';
import 'package:reelpin/components/chat/chat_question_bubble.dart';
import 'package:reelpin/components/chat/chat_thinking_stages.dart';
import 'package:reelpin/components/collections/share_to_collection_chat.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/screens/chat/partials/chat_attachment_sheet.dart';
import 'package:reelpin/components/chat/chat_composer.dart';
import 'package:reelpin/screens/chat/partials/chat_empty_state.dart';
import 'package:reelpin/screens/chat/partials/chat_thread_drawer.dart';
import 'package:reelpin/services/chat/chat_reel_cache.dart';
import 'package:reelpin/view_models/chat_view_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _drawerKey = GlobalKey<ScaffoldState>();
  final List<ChatAttachment> _pending = [];

  /// Fills in reels a citation names that the paginated library hasn't
  /// paged into memory yet. Lives here rather than lower in the tree so it
  /// survives switching between threads — a reel already fetched for one
  /// thread's answer is not re-fetched for another's.
  late final ChatReelCache _reelCache = ChatReelCache(
    (reelId) => ref.read(reelRepositoryProvider).getReel(reelId),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = ref.read(chatViewModelProvider);
      unawaited(viewModel.hydrate());
      unawaited(viewModel.loadSuggestions());
      // Same count Discover's RECENT SAVES badge shows. Loaded here too
      // rather than only relying on the Discover tab having been visited
      // first, so it's correct even if Chat is the first tab the user opens.
      final discoverViewModel = ref.read(discoverViewModelProvider);
      if (discoverViewModel.discover == null) {
        unawaited(discoverViewModel.loadDiscover());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  /// AppShell floats its nav bar over this screen, so the composer has to
  /// clear it. Mirrors `_floatingNavHeight` + `_floatingNavBottomInset` in
  /// app_shell.dart, the same way collections_screen.dart does for its grid.
  /// The Scaffold has `resizeToAvoidBottomInset: false`, so this is the only
  /// thing moving the composer for the keyboard too — once the keyboard is
  /// taller than the nav-bar clearance, its inset wins outright, tracking it
  /// 1:1 instead of stacking on top of Scaffold's own (separately animated)
  /// keyboard padding, which is what left a gap behind on some devices.
  double _composerBottomClearance(BuildContext context) {
    final navBarClearance =
        MediaQuery.viewPaddingOf(context).bottom + 14 + 56 + 12;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return keyboardInset > navBarClearance ? keyboardInset : navBarClearance;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(chatViewModelProvider);
    final discoverViewModel = ref.watch(discoverViewModelProvider);
    final thread = viewModel.activeThread;
    // Consumed as soon as it's read: the seed is meant to reach the composer
    // exactly once. consumeSeed() doesn't notifyListeners, so doing this here
    // doesn't trigger a re-entrant rebuild.
    final seedText = viewModel.seedText;
    final seedAttachments = viewModel.seedAttachments;
    if (seedText.isNotEmpty || seedAttachments.isNotEmpty) {
      if (seedAttachments.isNotEmpty) _pending.addAll(seedAttachments);
      viewModel.consumeSeed();
    }

    return Scaffold(
      key: _drawerKey,
      backgroundColor: AppColors.bg(context),
      // _composerBottomClearance takes over keyboard avoidance itself (it
      // already has to, to swap the floating-nav-bar clearance out for the
      // keyboard once it's taller). Leaving this true had Scaffold's own
      // AnimatedPadding push the body up *as well*, and the two didn't
      // settle on the same final offset — a gap was left between the
      // composer and the keyboard.
      resizeToAvoidBottomInset: false,
      drawer: ChatThreadDrawer(
        threads: viewModel.threads,
        onOpen: (id) {
          Navigator.of(context).pop();
          viewModel.openThread(id);
        },
        onNewChat: () {
          Navigator.of(context).pop();
          viewModel.startNewThread();
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: thread == null
                  ? ChatEmptyState(
                      // Same source as Discover's RECENT SAVES count, so the
                      // two screens never disagree. Falls back to the reel
                      // repository's own total while Discover's data is
                      // still loading, rather than showing 0.
                      savedCount:
                          discoverViewModel.discover?.recentSavesCount ??
                          ref.read(reelRepositoryProvider).totalCount,
                      // Backend suggestions are personalized to the user's
                      // actual saves (recency, categories); the local ones
                      // are a generic fallback for when that call hasn't
                      // resolved yet or fails.
                      suggestions: viewModel.suggestions.isNotEmpty
                          ? viewModel.suggestions
                          : _suggestions(),
                      onSuggestionTap: (text) {
                        unawaited(viewModel.send(text));
                        _scrollToBottom();
                      },
                    )
                  : _buildThread(thread, viewModel),
            ),
            // Builder scopes the MediaQuery read in _composerBottomClearance
            // to just this subtree, so the keyboard's open/close animation
            // (which changes viewInsets every frame) doesn't also rebuild
            // the thread list and header above it — that full rebuild was
            // the laggy feeling on tapping the input.
            Builder(
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: _composerBottomClearance(context),
                ),
                child: ChatComposer(
                  enabled: !viewModel.isAnswering,
                  initialText: seedText,
                  pending: _pending,
                  onRemoveAttachment: (i) =>
                      setState(() => _pending.removeAt(i)),
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
                    unawaited(viewModel.send(text, attachments: attachments));
                    _scrollToBottom();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.fg(context))),
      ),
      child: Row(
        children: [
          _headerButton(
            context,
            Icons.menu,
            () => _drawerKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Text(
              'ASK YOUR SAVES',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          _headerButton(
            context,
            Icons.add,
            () => ref.read(chatViewModelProvider).startNewThread(),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.bg(context),
          border: Border.all(color: AppColors.fg(context)),
          boxShadow: AppTheme.brutalShadowSmall(context),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppColors.fg(context)),
      ),
    );
  }

  Widget _buildThread(ChatThread thread, ChatViewModel viewModel) {
    final messages = thread.messages;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = messages[index];
        if (message.role == MessageRole.user) {
          return ChatQuestionBubble(message: message);
        }
        if (message.status == MessageStatus.sending) {
          return ChatThinkingStages(stages: viewModel.stages);
        }
        // retryLast() only redoes the thread's last question, so a failed
        // message earlier in the thread — followed by a later, successful
        // answer — must not offer a RETRY that would destroy it.
        final isLastMessage = index == messages.length - 1;
        return ChatAnswerCard(
          message: message,
          onRetry: isLastMessage
              ? () => unawaited(viewModel.retryLast())
              : null,
          library: ref.read(reelRepositoryProvider).cachedReels,
          reelCache: _reelCache,
          onTapReel: (reel) =>
              Navigator.of(context).push(reelDetailRoute(reel)),
          onSaveToCollection: () => unawaited(
            shareToCollectionChat(
              context,
              ref,
              messages: messages,
              index: index,
            ),
          ),
        );
      },
    );
  }

  /// Drawn from the user's own categories where possible, so the prompts on
  /// screen are about their library rather than a generic demo. Topped up
  /// with generic fallbacks rather than a single one, since a library with
  /// little category variety would otherwise show just one suggestion.
  static const _fallbackSuggestions = [
    'What have I been saving most this month?',
    'Summarize everything I saved this week.',
    'What did I save that I still need to try?',
  ];

  List<String> _suggestions() {
    final reels = ref.read(reelRepositoryProvider).cachedReels;
    final categories = reels
        .map((reel) => reel.category)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .take(3)
        .toList();

    return [
      for (final category in categories)
        'What did I save about ${category.toLowerCase()}?',
      ..._fallbackSuggestions,
    ].take(3).toList();
  }
}
