import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/folder.dart';
import '../models/reel.dart';
import '../providers/app_providers.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/folders_viewmodel.dart';
import '../widgets/reel_card.dart';
import 'reel_detail_screen.dart';

enum _FolderReelAction { transfer, remove }

class FolderDetailScreen extends ConsumerStatefulWidget {
  const FolderDetailScreen({super.key, required this.folder});

  final FolderSummary folder;

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  late FolderSummary _folder;
  bool _didRequestLoad = false;

  @override
  void initState() {
    super.initState();
    _folder = widget.folder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRequestLoad) return;
      _didRequestLoad = true;
      unawaited(
        ref
            .read(foldersViewModelProvider)
            .loadFolder(_folder.id, forceRefresh: true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final foldersVm = ref.watch(foldersViewModelProvider);
    final detail = foldersVm.detailFor(_folder.id);
    final activeFolder = detail?.folder ?? _folder;
    _folder = activeFolder;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 280) {
              foldersVm.loadMoreFolderReels(_folder.id);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(foldersViewModelProvider)
                .loadFolder(_folder.id, forceRefresh: true),
            color: AppTheme.fg(context),
            backgroundColor: AppTheme.yellow,
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
                    child: _buildHeader(context, foldersVm),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.inset(20),
                      0,
                      layout.inset(20),
                      layout.gap(16),
                    ),
                    child: _buildStickyNote(context, activeFolder),
                  ),
                ),
                if (foldersVm.isLoadingDetail && detail == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildLoadingState(context),
                  )
                else if (foldersVm.detailError != null && detail == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildErrorState(context, foldersVm),
                  )
                else if ((detail?.reels ?? const <Reel>[]).isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else ...[
                  _buildReelGrid(context, detail!.reels),
                  _buildPaginationState(context, foldersVm, detail),
                ],
                SliverToBoxAdapter(child: SizedBox(height: layout.gap(96))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FoldersViewModel foldersVm) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: layout.inset(40),
            height: layout.inset(40),
            decoration: AppTheme.brutalBox(context, shadow: true),
            child: Icon(
              Icons.arrow_back,
              color: AppTheme.fg(context),
              size: layout.inset(20),
            ),
          ),
        ),
        SizedBox(width: layout.inset(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _folder.name.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(18, maxFactor: 1.05),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: layout.gap(4)),
              Text(
                '${_folder.reelCount} REEL${_folder.reelCount == 1 ? '' : 'S'}',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: layout.font(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: foldersVm.isMutating ? null : () => _showEditFolderSheet(),
          child: Container(
            width: layout.inset(40),
            height: layout.inset(40),
            decoration: AppTheme.brutalBox(context, shadow: true),
            child: Icon(
              Icons.edit,
              color: AppTheme.fg(context),
              size: layout.inset(18),
            ),
          ),
        ),
        SizedBox(width: layout.inset(10)),
        GestureDetector(
          onTap: foldersVm.isMutating ? null : () => _confirmDeleteFolder(),
          child: Container(
            width: layout.inset(40),
            height: layout.inset(40),
            decoration: AppTheme.brutalBox(
              context,
              color: AppTheme.destructive,
              shadow: true,
            ),
            child: Icon(
              Icons.delete,
              color: AppTheme.white,
              size: layout.inset(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyNote(BuildContext context, FolderSummary folder) {
    final layout = AppLayout.of(context);
    final note = folder.note?.trim();
    return SizedBox(
      height: layout.gap(170),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: layout.inset(14),
            right: layout.inset(6),
            top: layout.gap(18),
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.black.withAlpha(70),
                border: Border.all(color: AppTheme.fg(context), width: 2),
              ),
            ),
          ),
          Positioned.fill(
            top: layout.gap(8),
            right: layout.inset(8),
            child: Transform.rotate(
              angle: -0.025,
              child: ClipPath(
                clipper: _StickyNoteClipper(),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    layout.inset(22),
                    layout.gap(38),
                    layout.inset(22),
                    layout.gap(18),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEA75),
                    border: Border.all(color: AppTheme.fg(context), width: 2),
                    boxShadow: AppTheme.brutalShadowSmall(context),
                  ),
                  child: Text(
                    note == null || note.isEmpty
                        ? 'NO NOTE YET. TAP EDIT TO ADD ONE.'
                        : note.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -layout.gap(10),
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.28,
                child: Image.asset(
                  'assets/images/pin.png',
                  width: layout.inset(42),
                  height: layout.inset(42),
                ),
              ),
            ),
          ),
          Positioned(
            top: layout.gap(27),
            left: 0,
            right: 0,
            child: Center(
              child: Transform.translate(
                offset: Offset(-layout.inset(2), 0),
                child: Container(
                  width: layout.inset(5),
                  height: layout.inset(5),
                  decoration: BoxDecoration(
                    color: AppTheme.black.withAlpha(180),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.fg(context).withAlpha(110),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: layout.inset(20),
            bottom: layout.gap(4),
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: layout.inset(48),
                height: layout.gap(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD94A),
                  border: Border.all(color: AppTheme.fg(context), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelGrid(BuildContext context, List<Reel> reels) {
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReelDetailScreen(reel: reel),
                        ),
                      );
                    },
                    onLongPress: () => _showReelActions(reel),
                  ),
                ),
              ),
            );
          }, childCount: reels.length),
        ),
      ),
    );
  }

  Widget _buildPaginationState(
    BuildContext context,
    FoldersViewModel foldersVm,
    FolderDetailResponse detail,
  ) {
    final layout = AppLayout.of(context);
    if (!foldersVm.isLoadingDetail || !detail.pagination.hasMore) {
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
              color: AppTheme.fg(context),
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final layout = AppLayout.of(context);
    return Center(
      child: SizedBox(
        width: layout.inset(36),
        height: layout.inset(36),
        child: CircularProgressIndicator(
          color: AppTheme.fg(context),
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, FoldersViewModel foldersVm) {
    final layout = AppLayout.of(context);
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: layout.inset(28)),
        padding: EdgeInsets.all(layout.inset(22)),
        decoration: AppTheme.brutalCard(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'COULD NOT LOAD FOLDER',
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
                fontSize: layout.font(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(8)),
            Text(
              foldersVm.detailError ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontSize: layout.font(11),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final layout = AppLayout.of(context);
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: layout.inset(28)),
        padding: EdgeInsets.all(layout.inset(22)),
        decoration: AppTheme.brutalCard(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: layout.inset(52),
              height: layout.inset(44),
              decoration: AppTheme.brutalBox(
                context,
                color: AppTheme.yellow,
                shadow: false,
              ),
              child: Icon(
                Icons.folder_open,
                color: AppTheme.black,
                size: layout.inset(26),
              ),
            ),
            SizedBox(height: layout.gap(14)),
            Text(
              'THIS FOLDER IS EMPTY',
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
                fontSize: layout.font(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: layout.gap(8)),
            Text(
              'LONG-PRESS REELS ON HOME TO CREATE A NEW FOLDER FROM A SELECTION.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontSize: layout.font(11),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditFolderSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditFolderSheet(folder: _folder),
    );
  }

  Future<void> _showReelActions(Reel reel) async {
    final action = await showModalBottomSheet<_FolderReelAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final layout = AppLayout.of(context);
        return Container(
          padding: EdgeInsets.fromLTRB(
            layout.inset(24),
            layout.gap(18),
            layout.inset(24),
            layout.gap(24),
          ),
          decoration: AppTheme.brutalCard(context, color: AppTheme.bg(context)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: layout.inset(40),
                    height: layout.gap(4),
                    color: AppTheme.fg(context),
                  ),
                ),
                SizedBox(height: layout.gap(18)),
                Text(
                  'FOLDER ACTIONS',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
                    fontSize: layout.font(17),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: layout.gap(8)),
                Text(
                  reel.title.isEmpty
                      ? 'CHOOSE WHAT TO DO WITH THIS REEL.'
                      : reel.title,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.textSec(context),
                    fontSize: layout.font(11),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: layout.gap(18)),
                _buildReelActionButton(
                  context,
                  label: 'TRANSFER TO FOLDER',
                  color: AppTheme.blue,
                  icon: Icons.drive_file_move,
                  onTap: () =>
                      Navigator.pop(context, _FolderReelAction.transfer),
                ),
                SizedBox(height: layout.gap(12)),
                _buildReelActionButton(
                  context,
                  label: 'REMOVE FROM FOLDER',
                  color: AppTheme.yellow,
                  icon: Icons.delete_outline,
                  onTap: () => Navigator.pop(context, _FolderReelAction.remove),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    switch (action) {
      case _FolderReelAction.transfer:
        await _showTransferFolderSheet(reel);
      case _FolderReelAction.remove:
        await _confirmRemoveReel(reel);
      case null:
        break;
    }
  }

  Widget _buildReelActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final layout = AppLayout.of(context);
    final textColor = color == AppTheme.blue ? AppTheme.white : AppTheme.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: layout.inset(14),
          vertical: layout.gap(13),
        ),
        decoration: AppTheme.brutalBox(context, color: color, shadow: true),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: layout.inset(18)),
            SizedBox(width: layout.inset(10)),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: textColor,
                  fontSize: layout.font(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransferFolderSheet(Reel reel) async {
    final foldersVm = ref.read(foldersViewModelProvider);
    if (foldersVm.folders.isEmpty && !foldersVm.isLoadingFolders) {
      await foldersVm.loadFolders();
    }
    if (!mounted) return;

    final target = await showModalBottomSheet<FolderSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final vm = ref.watch(foldersViewModelProvider);
            final targets = vm.folders
                .where((folder) => folder.id != _folder.id)
                .toList(growable: false);
            return _TransferFolderSheet(
              folders: targets,
              isLoading: vm.isLoadingFolders,
              isMutating: vm.isMutating,
            );
          },
        );
      },
    );

    if (target == null || !mounted) return;
    await _transferReelToFolder(reel, target);
  }

  Future<void> _transferReelToFolder(Reel reel, FolderSummary target) async {
    try {
      await ref
          .read(foldersViewModelProvider)
          .addReelsToFolder(
            folderId: target.id,
            reelIds: [reel.id],
            moveExisting: true,
          );
      await ref
          .read(foldersViewModelProvider)
          .loadFolder(_folder.id, forceRefresh: true);
      await ref
          .read(discoverViewModelProvider)
          .loadDiscover(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'MOVED TO ${target.name.toUpperCase()}',
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              e,
              fallbackMessage: 'Could not transfer the reel right now.',
            ),
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
        ),
      );
    }
  }

  Future<void> _confirmRemoveReel(Reel reel) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppTheme.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'REMOVE FROM FOLDER?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          reel.title.isEmpty ? 'The reel stays saved in ReelPin.' : reel.title,
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSec(context),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.yellow,
                border: Border.all(color: AppTheme.fg(context), width: 2),
                boxShadow: AppTheme.brutalShadowSmall(context),
              ),
              child: Text(
                'REMOVE',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;
    try {
      await ref
          .read(foldersViewModelProvider)
          .removeReelFromFolder(folderId: _folder.id, reelId: reel.id);
      await ref
          .read(discoverViewModelProvider)
          .loadDiscover(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              e,
              fallbackMessage: 'Could not remove the reel from this folder.',
            ),
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
        ),
      );
    }
  }

  Future<void> _confirmDeleteFolder() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppTheme.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'DELETE FOLDER?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'The reels stay saved. Only this folder is removed.',
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSec(context),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.destructive,
                border: Border.all(color: AppTheme.fg(context), width: 2),
                boxShadow: AppTheme.brutalShadowSmall(context),
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;
    try {
      await ref.read(foldersViewModelProvider).deleteFolder(_folder.id);
      if (!mounted) return;
      await ref
          .read(discoverViewModelProvider)
          .loadDiscover(forceRefresh: true);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              e,
              fallbackMessage: 'Could not delete the folder right now.',
            ),
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
        ),
      );
    }
  }
}

class _EditFolderSheet extends ConsumerStatefulWidget {
  const _EditFolderSheet({required this.folder});

  final FolderSummary folder;

  @override
  ConsumerState<_EditFolderSheet> createState() => _EditFolderSheetState();
}

class _EditFolderSheetState extends ConsumerState<_EditFolderSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder.name);
    _noteController = TextEditingController(text: widget.folder.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          layout.inset(24),
          layout.gap(18),
          layout.inset(24),
          layout.gap(24),
        ),
        decoration: AppTheme.brutalCard(context, color: AppTheme.bg(context)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: layout.inset(40),
                  height: layout.gap(4),
                  color: AppTheme.fg(context),
                ),
              ),
              SizedBox(height: layout.gap(18)),
              Text(
                'EDIT FOLDER',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(17),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(16)),
              _buildField(
                context,
                controller: _nameController,
                label: 'FOLDER NAME',
                maxLength: 20,
                maxLines: 1,
              ),
              SizedBox(height: layout.gap(12)),
              _buildField(
                context,
                controller: _noteController,
                label: 'STICKY NOTE',
                maxLength: 80,
                maxLines: 3,
              ),
              if (_error != null) ...[
                SizedBox(height: layout.gap(12)),
                Text(
                  _error!.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.destructive,
                    fontSize: layout.font(10),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
              SizedBox(height: layout.gap(18)),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: layout.gap(14)),
                  decoration: AppTheme.brutalBox(
                    context,
                    color: _isSaving
                        ? AppTheme.surfaceElevatedColor(context)
                        : AppTheme.yellow,
                    shadow: true,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isSaving ? 'SAVING...' : 'SAVE FOLDER',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required int maxLength,
    required int maxLines,
  }) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: layout.font(10),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: layout.gap(6)),
        Container(
          decoration: AppTheme.brutalBox(context, shadow: false),
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: layout.font(13),
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppTheme.fg(context),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterStyle: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontSize: layout.font(9),
                fontWeight: FontWeight.w700,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: layout.inset(12),
                vertical: layout.gap(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Folder name is required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(foldersViewModelProvider)
          .updateFolder(folderId: widget.folder.id, name: name, note: note);
      if (!mounted) return;
      await ref
          .read(discoverViewModelProvider)
          .loadDiscover(forceRefresh: true);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = userFacingErrorMessage(
          e,
          fallbackMessage: 'Could not update the folder right now.',
        );
      });
    }
  }
}

class _TransferFolderSheet extends StatelessWidget {
  const _TransferFolderSheet({
    required this.folders,
    required this.isLoading,
    required this.isMutating,
  });

  final List<FolderSummary> folders;
  final bool isLoading;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.68;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          layout.inset(24),
          layout.gap(18),
          layout.inset(24),
          layout.gap(24),
        ),
        decoration: AppTheme.brutalCard(context, color: AppTheme.bg(context)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: layout.inset(40),
                  height: layout.gap(4),
                  color: AppTheme.fg(context),
                ),
              ),
              SizedBox(height: layout.gap(18)),
              Text(
                'TRANSFER TO',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(17),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(16)),
              if (isLoading && folders.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: layout.gap(28)),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.fg(context),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (folders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(layout.inset(16)),
                  decoration: AppTheme.brutalBox(
                    context,
                    color: AppTheme.surfaceElevatedColor(context),
                    shadow: false,
                  ),
                  child: Text(
                    'NO OTHER FOLDERS YET.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSec(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: folders.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: layout.gap(12),
                      crossAxisSpacing: layout.inset(12),
                      childAspectRatio: 1.22,
                    ),
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return GestureDetector(
                        onTap: isMutating
                            ? null
                            : () => Navigator.pop(context, folder),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildTransferFolderPreview(
                                context,
                                folder,
                                _folderAccentForIndex(index),
                              ),
                              if (isMutating)
                                Positioned.fill(
                                  child: Container(
                                    color: AppTheme.bg(context).withAlpha(180),
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: layout.inset(18),
                                      height: layout.inset(18),
                                      child: CircularProgressIndicator(
                                        color: AppTheme.fg(context),
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _folderAccentForIndex(int index) {
    const colors = [
      Color(0xFF7DB5FF),
      AppTheme.yellow,
      Color(0xFFFF6B6B),
      AppTheme.cyan,
      AppTheme.neonGreen,
    ];
    return colors[index % colors.length];
  }

  Widget _buildTransferFolderPreview(
    BuildContext context,
    FolderSummary folder,
    Color accent,
  ) {
    return SizedBox(
      width: 152,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 12,
            left: 10,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.black,
                border: Border.all(color: AppTheme.fg(context), width: 1.5),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 18,
            right: 16,
            height: 38,
            child: Transform.rotate(
              angle: -0.025,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg(context),
                  border: Border.all(color: AppTheme.fg(context), width: 1.5),
                ),
              ),
            ),
          ),
          Positioned(
            top: 15,
            left: 0,
            right: 7,
            bottom: 5,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 70,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent,
                      border: Border.all(
                        color: AppTheme.fg(context),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 9),
                    decoration: BoxDecoration(
                      color: accent,
                      border: Border.all(
                        color: AppTheme.fg(context),
                        width: 1.5,
                      ),
                      boxShadow: AppTheme.brutalShadowSmall(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name.toUpperCase(),
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          '${folder.reelCount} REEL${folder.reelCount == 1 ? '' : 'S'}',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyNoteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 10, size.height - 18)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height + 8,
        0,
        size.height - 8,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
