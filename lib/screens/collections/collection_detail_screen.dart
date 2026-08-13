import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/reels/reel_card.dart';
import 'package:reelpin/components/common/app_back_button.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/collections/collection_form_sheet.dart';
import 'package:reelpin/screens/collections/share_collection_sheet.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_loader_screen.dart';
import 'package:reelpin/services/sharing/shared_collection_prefetch.dart';
import 'package:reelpin/utils/error_message.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

part 'partials/collection_sticky_note.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.sharedToken,
    this.initialName,
  });

  final String collectionId;

  /// When set, the screen renders a read-only shared collection fetched with
  /// the capability token (the viewer may not be a member).
  final String? sharedToken;
  final String? initialName;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isShared) {
        unawaited(_loadShared());
      } else {
        unawaited(
          ref
              .read(collectionsViewModelProvider)
              .loadCollectionDetail(widget.collectionId),
        );
      }
    });
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
    return ref
        .read(collectionsViewModelProvider)
        .loadCollectionDetail(widget.collectionId, forceRefresh: true);
  }

  Future<void> _saveToLibrary(Reel reel) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reelRepositoryProvider).enqueueReelProcessing(reel.url);
      messenger.showSnackBar(
        const SnackBar(content: Text('Saving to your library...')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save this reel.')),
      );
    }
  }

  Future<void> _edit(CollectionSummary collection) async {
    await showCollectionFormSheet(context, collection: collection);
  }

  Future<void> _confirmDelete(CollectionSummary collection) async {
    final ok = await _confirm(
      context,
      'DELETE COLLECTION?',
      'THIS REMOVES THE COLLECTION FOR EVERYONE. SAVED REELS STAY IN YOUR '
          'LIBRARY.',
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
    final ok = await _confirm(
      context,
      'LEAVE COLLECTION?',
      'YOU WILL LOSE ACCESS TO IT.',
    );
    if (ok != true) return;
    await _runGuarded(
      () => ref.read(collectionsViewModelProvider).leave(collection.id),
      fallback: 'Could not leave the collection.',
      popOnSuccess: true,
    );
  }

  Future<void> _confirmRemoveReel(Reel reel) async {
    final ok = await _confirm(
      context,
      'REMOVE FROM COLLECTION?',
      'THE REEL STAYS IN YOUR LIBRARY.',
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
                    child: _buildHeader(context, vm, collection),
                  ),
                ),
                if (widget.isShared && detail != null)
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
                if (collection != null)
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
                        // Editing lives on the note now, not in the app bar:
                        // the note is what you are editing, and the header was
                        // carrying four actions.
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
                ),
                SliverToBoxAdapter(child: SizedBox(height: layout.gap(96))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CollectionsViewModel vm,
    CollectionSummary? collection,
  ) {
    final layout = AppLayout.of(context);
    final title = collection?.name ?? widget.initialName ?? 'COLLECTION';
    final count = collection?.itemCount ?? 0;
    final isOwner = !widget.isShared && (collection?.isOwner ?? false);

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
                '$count REEL${count == 1 ? '' : 'S'}',
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
    if (reels.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageCard(
            icon: Icons.folder_open,
            title: 'THIS COLLECTION IS EMPTY',
            body: canEdit
                ? 'ADD REELS FROM ANY REEL SCREEN, OR SHARE SOMETHING INTO IT.'
                : 'NOTHING HAS BEEN ADDED HERE YET.',
          ),
        ),
      ];
    }
    return [
      _buildReelGrid(context, reels, canEdit: canEdit),
      _buildPaginationState(context, detail!),
    ];
  }

  Widget _buildReelGrid(
    BuildContext context,
    List<Reel> reels, {
    required bool canEdit,
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
            final reel = reels[index];
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
                      if (widget.isShared) {
                        unawaited(_saveToLibrary(reel));
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReelDetailLoaderScreen(reelId: reel.id),
                        ),
                      );
                    },
                    onDelete: canEdit ? () => _confirmRemoveReel(reel) : null,
                  ),
                ),
              ),
            );
          }, childCount: reels.length),
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
      decoration: AppTheme.brutalBox(context, color: AppColors.yellow),
      child: Row(
        children: [
          Icon(Icons.link, size: layout.inset(16), color: AppColors.black),
          SizedBox(width: layout.inset(8)),
          Expanded(
            child: Text(
              ownerName != null
                  ? 'SHARED BY ${ownerName!.toUpperCase()} · VIEW ONLY'
                  : 'SHARED COLLECTION · VIEW ONLY',
              style: GoogleFonts.spaceMono(
                color: AppColors.black,
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

Future<bool?> _confirm(BuildContext context, String title, String body) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final layout = AppLayout.of(context);
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(layout.inset(22)),
          decoration: AppTheme.brutalCard(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(15),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(10)),
              Text(
                body,
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(11),
                  height: 1.5,
                ),
              ),
              SizedBox(height: layout.gap(20)),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: layout.gap(12)),
                        decoration: AppTheme.brutalBox(context, shadow: false),
                        alignment: Alignment.center,
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.spaceMono(
                            color: AppColors.fg(context),
                            fontSize: layout.font(11),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: layout.inset(10)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: layout.gap(12)),
                        decoration: AppTheme.brutalBox(
                          context,
                          color: AppColors.destructive,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'CONFIRM',
                          style: GoogleFonts.spaceMono(
                            color: AppColors.white,
                            fontSize: layout.font(11),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
