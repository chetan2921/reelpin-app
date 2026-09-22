import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/chat/chat_thread_drawer.dart';
import 'package:reelpin/components/common/app_back_button.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/collections/partials/collection_chat_panel.dart';
import 'package:reelpin/view_models/collection_chat_view_model.dart';

/// A collection's ASK screen: the private chat's layout — a sidebar of past
/// conversations, a new-chat button, the open thread and its composer —
/// scoped to one collection and shared with everyone in it.
class CollectionAskScreen extends ConsumerStatefulWidget {
  const CollectionAskScreen({
    super.key,
    required this.collectionId,
    required this.collectionName,
    required this.canEdit,
  });

  final String collectionId;
  final String collectionName;

  /// Owner or editor. A viewer can open every conversation but not ask.
  final bool canEdit;

  @override
  ConsumerState<CollectionAskScreen> createState() =>
      _CollectionAskScreenState();
}

class _CollectionAskScreenState extends ConsumerState<CollectionAskScreen> {
  final _drawerKey = GlobalKey<ScaffoldState>();

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(
      collectionChatViewModelProvider(widget.collectionId),
    );

    return Scaffold(
      key: _drawerKey,
      backgroundColor: AppColors.bg(context),
      drawer: ChatThreadDrawer(
        heading: 'THIS COLLECTION',
        // The drawer lists private-chat threads; a collection's are the same
        // shape for its purposes — an id to open and a title to show.
        threads: [
          for (final thread in viewModel.threads)
            ChatThread(
              id: thread.id,
              title: thread.title,
              createdAt: thread.updatedAt ?? _epoch,
              updatedAt: thread.updatedAt ?? _epoch,
            ),
        ],
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
            _buildHeader(context, viewModel),
            Expanded(
              child: CollectionChatPanel(
                collectionId: widget.collectionId,
                canEdit: widget.canEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CollectionChatViewModel viewModel) {
    final layout = AppLayout.of(context);
    // AppBackButton scales with layout.inset() while the boxed icon buttons
    // here are fixed pixels, so the two sides of the title only balance at
    // one particular screen scale if built as loose siblings with a
    // hand-tuned spacer. Giving both sides this same explicit width — built
    // from the same layout — keeps the title centred on any device.
    final sideWidth = layout.inset(40) + 8 + 28;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.fg(context))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: Row(
              children: [
                // The app's one shared back button — not a boxed icon like
                // the drawer/new-chat buttons here, matching every other
                // screen.
                const AppBackButton(),
                const SizedBox(width: 8),
                _headerButton(
                  context,
                  Icons.menu,
                  () => _drawerKey.currentState?.openDrawer(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ASK · ${widget.collectionName.toUpperCase()}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: _headerButton(
                context,
                Icons.add,
                viewModel.startNewThread,
              ),
            ),
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
}
