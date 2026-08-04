import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/components/collections/collection_folder_tile.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/collections/collection_detail_screen.dart';
import 'package:reelpin/screens/collections/collection_form_sheet.dart';
import 'package:reelpin/view_models/collections_view_model.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionsViewModelProvider).loadCollections();
    });
  }

  /// AppShell floats its nav bar over this screen, so anything anchored to the
  /// bottom has to clear it. Mirrors `_floatingNavHeight` +
  /// `_floatingNavBottomInset` in app_shell.dart.
  double _navBarClearance(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom + 14 + 56 + 12;
  }

  Future<void> _createCollection() async {
    final created = await showCollectionFormSheet(context);
    if (created == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionDetailScreen(collectionId: created.id),
      ),
    );
  }

  Future<void> _refresh() {
    return ref
        .read(collectionsViewModelProvider)
        .loadCollections(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(collectionsViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
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
                  child: _buildHeader(context, vm),
                ),
              ),
              ..._buildBody(context, vm),
              SliverToBoxAdapter(
                child: SizedBox(height: _navBarClearance(context) + 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CollectionsViewModel vm) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLLECTIONS',
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(18, maxFactor: 1.05),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(4)),
              Text(
                '${vm.collections.length} COLLECTION'
                '${vm.collections.length == 1 ? '' : 'S'}',
                style: GoogleFonts.spaceMono(
                  color: AppColors.textSec(context),
                  fontSize: layout.font(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: vm.isMutating ? null : _createCollection,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: layout.inset(14),
              vertical: layout.gap(10),
            ),
            decoration: AppTheme.brutalBox(context, color: AppColors.yellow),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: AppColors.black, size: layout.inset(16)),
                SizedBox(width: layout.inset(6)),
                Text(
                  'NEW',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.black,
                    fontSize: layout.font(11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody(BuildContext context, CollectionsViewModel vm) {
    if (vm.isLoadingCollections && vm.collections.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _LoadingState()),
      ];
    }
    if (vm.collectionsError != null && vm.collections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageCard(
            title: 'COULD NOT LOAD COLLECTIONS',
            body: vm.collectionsError!,
            onRetry: _refresh,
          ),
        ),
      ];
    }
    if (vm.collections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageCard(
            icon: Icons.create_new_folder,
            title: 'NO COLLECTIONS YET',
            body:
                'TAP NEW TO MAKE ONE. GIVE IT A NAME AND A STICKY NOTE, '
                'THEN START ADDING REELS.',
          ),
        ),
      ];
    }
    return [_buildGrid(context, vm.collections)];
  }

  Widget _buildGrid(BuildContext context, List<CollectionSummary> collections) {
    final layout = AppLayout.of(context);
    final columns = layout.gridColumns(compact: 2, regular: 2, wide: 3);
    final spacing = layout.inset(12);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: layout.inset(14)),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            // The folder artwork was drawn at 158x130.
            childAspectRatio: 1.2,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final collection = collections[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: columns,
              duration: const Duration(milliseconds: 300),
              child: ScaleAnimation(
                scale: 0.96,
                child: FadeInAnimation(
                  child: CollectionFolderTile(
                    collection: collection,
                    index: index,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CollectionDetailScreen(
                          collectionId: collection.id,
                          initialName: collection.name,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }, childCount: collections.length),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
