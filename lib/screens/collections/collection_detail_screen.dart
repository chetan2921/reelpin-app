import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/reels/processing_reel_card.dart';
import 'package:reelpin/components/reels/reel_card.dart';
import 'package:reelpin/components/common/app_back_button.dart';
import 'package:reelpin/components/common/confirm_dialog.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/chat_feature.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/components/collections/collection_form_sheet.dart';
import 'package:reelpin/components/collections/share_collection_sheet.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/screens/collections/partials/collection_chat_panel.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_loader_screen.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';
import 'package:reelpin/services/sharing/collection_link_cache.dart';
import 'package:reelpin/services/sharing/shared_collection_prefetch.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

part 'partials/collection_sticky_note.dart';
part 'partials/collection_tab_bar.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.sharedToken,
    this.sharedUrl,
    this.initialName,
    this.offerChat = chatEnabled,
  });

  final String collectionId;

  /// When set, the screen renders a read-only shared collection fetched with
  /// the capability token (the viewer may not be a member).
  final String? sharedToken;

  /// The share link this view was opened with, passed on when a viewer shares
  /// a reel from inside it.
  final String? sharedUrl;
  final String? initialName;

  /// Whether to offer the collection's shared AI thread. Defaults to this
  /// build's [chatEnabled]; tests pass true — the same way
  /// `AppShellController.forTest` injects it — since the const is always
  /// false under `flutter test`.
  final bool offerChat;

  bool get isShared => sharedToken != null;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  CollectionDetail? _shared;
  bool _loadingShared = false;
  String? _sharedError;

  /// This collection's own share link, when the owner minted one on this
  /// device. Null is normal — a link may be off, or was created elsewhere.
  String? _ownLinkUrl;

  /// Which tab is showing. Plain widget state rather than a view model: it is
  /// purely this screen's presentation, and opening on REELS every time is
  /// the right default.
  bool _chatTab = false;

  @override
  void initState() {
    super.initState();
    // Before the first frame, and synchronously: the SAVED grid already holds
    // this collection, so the screen can open on it instead of a spinner while
    // the reels are fetched.
    if (!widget.isShared) {
      ref
          .read(collectionsViewModelProvider)
          .seedDetailFromSummary(widget.collectionId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isShared) {
        unawaited(_loadShared());
      } else {
        // Paint the cached reels first, then refetch over the top: a reel
        // shared into this collection from outside the app lands server-side,
        // so a cached detail alone would never show it — but waiting on that
        // request before showing anything is what made every open feel slow.
        final vm = ref.read(collectionsViewModelProvider);
        unawaited(
          vm
              .hydrateDetailFromCache(widget.collectionId)
              .then(
                (_) => vm.loadCollectionDetail(
                  widget.collectionId,
                  forceRefresh: true,
                ),
              ),
        );
        unawaited(_loadOwnLink());
      }
    });
  }

  Future<void> _loadOwnLink() async {
    final url = await CollectionLinkCache.instance.read(widget.collectionId);
    if (mounted) setState(() => _ownLinkUrl = url);
  }

  /// The link to hand on when a reel is shared from in here. Nothing to pass
  /// when the collection has no link — a dead URL is worse than none.
  String? get _collectionShareUrl {
    if (widget.isShared) return widget.sharedUrl;
    final collection = ref
        .read(collectionsViewModelProvider)
        .detailFor(widget.collectionId)
        ?.collection;
    return (collection?.hasLink ?? false) ? _ownLinkUrl : null;
  }

  Future<void> _loadShared() async {
    setState(() {
      _loadingShared = true;
      _sharedError = null;
    });
    try {
      // Started while the splash was still up when the app was launched from
      // this link, so on that path there is usually nothing left to wait for.
      final detail =
          await (SharedCollectionPrefetch.take(widget.sharedToken!) ??
              ref
                  .read(collectionsHttpProvider)
                  .getSharedCollection(widget.sharedToken!));
      if (mounted) setState(() => _shared = detail);
    } catch (e) {
      if (mounted) {
        setState(
          () => _sharedError = userFacingErrorMessage(
            e,
            fallbackMessage: 'Could not open this shared collection.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingShared = false);
    }
  }

  Future<void> _refresh() {
    return Future.wait([
      ref
          .read(collectionsViewModelProvider)
          .loadCollectionDetail(widget.collectionId, forceRefresh: true),
      ref.read(processingJobsViewModelProvider).refresh(),
    ]);
  }

  Future<void> _edit(CollectionSummary collection) async {
    await showCollectionFormSheet(context, collection: collection);
  }

  Future<void> _confirmDelete(CollectionSummary collection) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete collection?',
      message:
          'This removes the collection for everyone. Your pins stay in your '
          'library.',
    );
    if (ok != true) return;
    await _runGuarded(
      () => ref
          .read(collectionsViewModelProvider)
          .deleteCollection(collection.id),
      fallback: 'Could not delete the collection.',
      popOnSuccess: true,
    );
  }

  Future<void> _confirmLeave(CollectionSummary collection) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Leave collection?',
      message: 'You will lose access to it.',
      confirmLabel: 'LEAVE',
    );
    if (ok != true) return;
    await _runGuarded(
      () => ref.read(collectionsViewModelProvider).leave(collection.id),
      fallback: 'Could not leave the collection.',
      popOnSuccess: true,
    );
  }

  Future<void> _confirmRemoveReel(Reel reel) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove from collection?',
      message: 'It stays in your library.',
      confirmLabel: 'REMOVE',
    );
    if (ok != true) return;
    await _runGuarded(
      () => ref
          .read(collectionsViewModelProvider)
          .removeReel(collectionId: widget.collectionId, reelId: reel.id),
      fallback: 'Could not remove this reel.',
    );
  }

  /// The viewmodel rethrows on failure, so every mutation needs this or the
  /// error is invisible.
  Future<void> _runGuarded(
    Future<void> Function() action, {
    required String fallback,
    bool popOnSuccess = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action();
      if (popOnSuccess && mounted) navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(userFacingErrorMessage(e, fallbackMessage: fallback)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(collectionsViewModelProvider);

    final CollectionDetail? detail;
    final CollectionSummary? collection;
    if (widget.isShared) {
      detail = _shared;
      collection = _shared?.collection;
    } else {
      detail = vm.detailFor(widget.collectionId);
      collection = detail?.collection;
    }

    final isLoading = widget.isShared ? _loadingShared : vm.isLoadingDetail;
    final error = widget.isShared ? _sharedError : vm.detailError;
    final canEdit = !widget.isShared && (detail?.canEdit ?? false);
    // A link visitor and an invited viewer are in the same position, so both
    // get the strip. Keyed off the role rather than the detail's can_edit
    // flag, since role defaults to owner when the API omits it and a missing
    // flag must never label an owner's own collection view-only.
    final isViewOnly =
        widget.isShared || (collection != null && !collection.canEdit);
    final ownsReels = !widget.isShared && (collection?.isOwner ?? false);
    // A link visitor has no identity to attribute a question to, so the shared
    // thread is offered to members only.
    final showChatTab =
        widget.offerChat && !widget.isShared && collection != null;

    // Its own Scaffold rather than a branch inside the scroll view below, so
    // the REELS layout is left exactly as it was.
    if (showChatTab && _chatTab) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: SafeArea(
          bottom: false,
          child: _buildChatTab(
            context,
            vm,
            collection,
            canEdit: canEdit,
            ownerName: detail?.ownerName,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!widget.isShared &&
                notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 280) {
              unawaited(vm.loadMore(widget.collectionId));
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: widget.isShared ? _loadShared : _refresh,
            color: AppColors.fg(context),
            backgroundColor: AppColors.yellow,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.inset(20),
                      layout.gap(20),
                      layout.inset(20),
                      layout.gap(16),
                    ),
                    child: _buildHeader(
                      context,
                      vm,
                      collection,
                      canEdit: canEdit,
                      ownerName: detail?.ownerName,
                    ),
                  ),
                ),
                if (showChatTab)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        0,
                        layout.inset(20),
                        layout.gap(16),
                      ),
                      child: _CollectionTabBar(
                        chatSelected: false,
                        onSelect: _selectTab,
                      ),
                    ),
                  ),
                if (chatEnabled && collection != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        0,
                        layout.inset(20),
                        layout.gap(16),
                      ),
                      child: GestureDetector(
                        // `collection!`: null-promotion from the branch
                        // condition above doesn't survive into this closure.
                        onTap: () => openChat(
                          context,
                          ref,
                          seedAttachments: [
                            ChatAttachment(
                              kind: AttachmentKind.collection,
                              displayName: collection!.name,
                              collectionId: collection.id,
                            ),
                          ],
                          showAskTab: () =>
                              ref.read(appShellControllerProvider)?.showAsk(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            border: Border.all(color: AppColors.black),
                            boxShadow: AppTheme.inkShadowSmall,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/pin.png',
                                width: 15,
                                height: 15,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'ASK THIS COLLECTION',
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (detail != null && isViewOnly)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        0,
                        layout.inset(20),
                        layout.gap(16),
                      ),
                      child: _SharedBanner(ownerName: detail.ownerName),
                    ),
                  ),
                if (collection != null &&
                    collection.description.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        0,
                        layout.inset(20),
                        layout.gap(16),
                      ),
                      child: _CollectionStickyNote(
                        note: collection.description,
                        canEdit: canEdit,
                        // Editing lives on the note when there is one — the
                        // note is what you are editing. With no note the
                        // header carries the pencil instead.
                        onEdit: canEdit ? () => _edit(collection!) : null,
                      ),
                    ),
                  ),
                ..._buildContent(
                  context,
                  detail: detail,
                  isLoading: isLoading,
                  error: error,
                  canEdit: canEdit,
                  ownsReels: ownsReels,
                ),
                SliverToBoxAdapter(child: SizedBox(height: layout.gap(96))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(bool chat) => setState(() => _chatTab = chat);

  /// The CHAT tab pins the header rather than letting it scroll away with the
  /// content: a thread needs a stable list and composer, which a grid does not.
  Widget _buildChatTab(
    BuildContext context,
    CollectionsViewModel vm,
    CollectionSummary? collection, {
    required bool canEdit,
    required String? ownerName,
  }) {
    final layout = AppLayout.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.inset(20),
            layout.gap(20),
            layout.inset(20),
            layout.gap(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                context,
                vm,
                collection,
                canEdit: canEdit,
                ownerName: ownerName,
              ),
              SizedBox(height: layout.gap(16)),
              _CollectionTabBar(chatSelected: true, onSelect: _selectTab),
            ],
          ),
        ),
        Expanded(
          child: CollectionChatPanel(
            collectionId: widget.collectionId,
            canEdit: canEdit,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CollectionsViewModel vm,
    CollectionSummary? collection, {
    required bool canEdit,
    required String? ownerName,
  }) {
    final layout = AppLayout.of(context);
    final title = collection?.name ?? widget.initialName ?? 'COLLECTION';
    final count = collection?.itemCount ?? 0;
    final isOwner = !widget.isShared && (collection?.isOwner ?? false);
    // Whose collection this is, for everyone it was shared with. An editor
    // needs it as much as a viewer, so it sits in the header rather than in
    // the view-only strip.
    final owner = isOwner ? null : ownerName?.trim();
    final subtitle = owner == null || owner.isEmpty
        ? '$count PIN${count == 1 ? '' : 'S'}'
        : '$count PIN${count == 1 ? '' : 'S'} · BY ${owner.toUpperCase()}';

    return Row(
      children: [
        const AppBackButton(),
        SizedBox(width: layout.inset(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(18, maxFactor: 1.05),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: layout.gap(4)),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Only when there is no note to hang it off, so the header never
        // carries an action the note already offers.
        if (canEdit &&
            collection != null &&
            collection.description.trim().isEmpty) ...[
          _HeaderAction(
            icon: Icons.edit,
            onTap: vm.isMutating ? null : () => _edit(collection),
          ),
          SizedBox(width: layout.inset(10)),
        ],
        if (isOwner) ...[
          _HeaderAction(
            icon: Icons.ios_share,
            onTap: vm.isMutating
                ? null
                : () => showShareCollectionSheet(context, collection!.id),
          ),
          SizedBox(width: layout.inset(10)),
        ],
        if (collection != null && !widget.isShared)
          _HeaderAction(
            icon: isOwner ? Icons.delete : Icons.logout,
            color: AppColors.destructive,
            iconColor: AppColors.white,
            onTap: vm.isMutating
                ? null
                : () => isOwner
                      ? _confirmDelete(collection)
                      : _confirmLeave(collection),
          ),
      ],
    );
  }

  List<Widget> _buildContent(
    BuildContext context, {
    required bool ownsReels,
    required CollectionDetail? detail,
    required bool isLoading,
    required String? error,
    required bool canEdit,
  }) {
    if (isLoading && detail == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildLoading(context),
        ),
      ];
    }
    if (error != null && detail == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageCard(
            title: 'COULD NOT LOAD COLLECTION',
            body: error,
            onRetry: widget.isShared ? _loadShared : _refresh,
          ),
        ),
      ];
    }
    final reels = detail?.reels ?? const <Reel>[];
    // A shared collection is someone else's; our pending shares do not belong
    // in it.
    final processingJobs = widget.isShared
        ? const <ProcessingJob>[]
        : ref
              .watch(processingJobsViewModelProvider)
              .jobsForCollection(widget.collectionId);
    if (reels.isEmpty && processingJobs.isEmpty) {
      // Seeded from the summary, so the reels are still on their way. Claiming
      // the collection is empty here would be a lie that corrects itself a
      // second later.
      if (!widget.isShared &&
          ref
              .watch(collectionsViewModelProvider)
              .isDetailPlaceholder(widget.collectionId)) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildLoading(context),
          ),
        ];
      }
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageCard(
            icon: Icons.folder_open,
            title: 'THIS COLLECTION IS EMPTY',
            body: canEdit
                ? 'ADD PINS FROM ANY SAVED ITEM, OR SHARE SOMETHING INTO IT.'
                : 'NOTHING HAS BEEN ADDED HERE YET.',
          ),
        ),
      ];
    }
    return [
      _buildReelGrid(
        context,
        reels,
        canEdit: canEdit,
        ownsReels: ownsReels,
        processingJobs: processingJobs,
      ),
      _buildPaginationState(context, detail!),
    ];
  }

  Widget _buildReelGrid(
    BuildContext context,
    List<Reel> reels, {
    required bool canEdit,
    required bool ownsReels,
    required List<ProcessingJob> processingJobs,
  }) {
    final layout = AppLayout.of(context);
    final columns = layout.gridColumns(compact: 2, regular: 2, wide: 3);
    final spacing = layout.inset(12);
    final aspect = layout.gridAspect(
      compact: 0.74,
      regular: 0.80,
      wide: 0.88,
      tablet: 0.92,
    );

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: layout.inset(14)),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspect,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index < processingJobs.length) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                columnCount: columns,
                duration: const Duration(milliseconds: 300),
                child: ScaleAnimation(
                  scale: 0.96,
                  child: FadeInAnimation(
                    child: ProcessingReelCard(
                      job: processingJobs[index],
                      isSettling: ref
                          .read(processingJobsViewModelProvider)
                          .isSettling(processingJobs[index].id),
                    ),
                  ),
                ),
              );
            }
            final reel = reels[index - processingJobs.length];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: columns,
              duration: const Duration(milliseconds: 300),
              child: ScaleAnimation(
                scale: 0.96,
                child: FadeInAnimation(
                  child: ReelCard(
                    reel: reel,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ownsReels
                              ? ReelDetailLoaderScreen(
                                  reelId: reel.id,
                                  collectionUrl: _collectionShareUrl,
                                )
                              : ReelDetailScreen(
                                  reel: reel,
                                  readOnly: true,
                                  collectionUrl: _collectionShareUrl,
                                ),
                        ),
                      );
                    },
                    onDelete: canEdit ? () => _confirmRemoveReel(reel) : null,
                  ),
                ),
              ),
            );
          }, childCount: processingJobs.length + reels.length),
        ),
      ),
    );
  }

  Widget _buildPaginationState(BuildContext context, CollectionDetail detail) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(collectionsViewModelProvider);
    if (!vm.isLoadingDetail || !detail.pagination.hasMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: layout.gap(18)),
        child: Center(
          child: SizedBox(
            width: layout.inset(24),
            height: layout.inset(24),
            child: CircularProgressIndicator(
              color: AppColors.fg(context),
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final layout = AppLayout.of(context);
    return Center(
      child: SizedBox(
        width: layout.inset(36),
        height: layout.inset(36),
        child: CircularProgressIndicator(
          color: AppColors.fg(context),
          strokeWidth: 3,
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: layout.inset(40),
        height: layout.inset(40),
        decoration: AppTheme.brutalBox(context, color: color),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.fg(context),
          size: layout.inset(18),
        ),
      ),
    );
  }
}

/// Read-only strip shown when the collection was opened from a share link.
class _SharedBanner extends StatelessWidget {
  const _SharedBanner({this.ownerName});

  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.inset(14),
        vertical: layout.gap(10),
      ),
      decoration: AppTheme.brutalBox(context, color: AppColors.blue),
      child: Row(
        children: [
          Icon(Icons.link, size: layout.inset(16), color: AppColors.white),
          SizedBox(width: layout.inset(8)),
          Expanded(
            child: Text(
              ownerName != null
                  ? 'SHARED BY ${ownerName!.toUpperCase()} · VIEW ONLY'
                  : 'SHARED COLLECTION · VIEW ONLY',
              style: GoogleFonts.spaceMono(
                color: AppColors.white,
                fontSize: layout.font(10),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared shell for the empty and error states.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.body,
    this.icon,
    this.onRetry,
  });

  final String title;
  final String body;
  final IconData? icon;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: layout.inset(28)),
        padding: EdgeInsets.all(layout.inset(22)),
        decoration: AppTheme.brutalCard(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: layout.inset(52),
                height: layout.inset(44),
                decoration: AppTheme.brutalBox(
                  context,
                  color: AppColors.yellow,
                  shadow: false,
                ),
                child: Icon(
                  icon,
                  color: AppColors.black,
                  size: layout.inset(26),
                ),
              ),
              SizedBox(height: layout.gap(14)),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: layout.font(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(8)),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: layout.font(11),
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: layout.gap(16)),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.inset(20),
                    vertical: layout.gap(10),
                  ),
                  decoration: AppTheme.brutalBox(
                    context,
                    color: AppColors.yellow,
                  ),
                  child: Text(
                    'RETRY',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
