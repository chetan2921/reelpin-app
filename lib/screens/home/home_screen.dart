import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/view_models/reel_filters_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/components/reels/category_badge.dart';
import 'package:reelpin/components/reels/reel_card.dart';
import 'package:reelpin/components/common/confirm_dialog.dart';
import 'package:reelpin/components/collections/add_to_collection_sheet.dart';

part 'partials/filter_option.dart';
part 'partials/platform_filter_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onSearchTap, this.scrollController});

  final VoidCallback? onSearchTap;
  final ScrollController? scrollController;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _didRequestInitialLoad = false;

  /// Non-null once a long press has put the grid into selection mode. Empty
  /// is still selection mode — the user can deselect everything and the bar
  /// stays until they close it.
  Set<String>? _selection;

  bool get _isSelecting => _selection != null;

  void _startSelection(String reelId) {
    setState(() => _selection = {reelId});
  }

  void _toggleSelection(String reelId) {
    final current = _selection;
    if (current == null) return;
    setState(() {
      if (!current.remove(reelId)) current.add(reelId);
    });
  }

  void _endSelection() {
    setState(() => _selection = null);
  }

  Future<void> _addSelectionToCollection(HomeViewModel vm) async {
    final ids = _selection?.toList(growable: false) ?? const <String>[];
    if (ids.isEmpty) return;
    await showAddToCollectionSheet(context, ids);
    if (mounted) _endSelection();
  }

  Future<void> _deleteSelection(HomeViewModel vm) async {
    final ids = _selection?.toList(growable: false) ?? const <String>[];
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: ids.length == 1
          ? 'Delete this pin?'
          : 'Delete ${ids.length} pins?',
      message: 'This action cannot be undone.',
    );
    if (confirmed != true) return;
    for (final id in ids) {
      await vm.deleteReel(id);
    }
    if (mounted) _endSelection();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRequestInitialLoad) return;
      _didRequestInitialLoad = true;
      final vm = ref.read(homeViewModelProvider);
      final filtersVm = ref.read(reelFiltersViewModelProvider);
      // Always revalidate, even when restored content is already on screen —
      // both calls no-op while a load is already in flight.
      if (!vm.isLoading) {
        vm.loadReels(forceRefresh: true);
      }
      if (!filtersVm.isLoading) {
        filtersVm.loadFilters(forceRefresh: true);
      }
    });
  }

  /// Single source of truth for "the library is empty", so the category row and
  /// the content branch below can never disagree about which one is showing.
  bool _isEmptyStateVisible(HomeViewModel vm) {
    if (vm.isLoading && vm.reels.isEmpty) return false;
    if (vm.error != null && vm.reels.isEmpty) return false;
    // vm.isEmpty stays false until a load has actually settled, so this cannot
    // claim the library is empty before anything has looked at it.
    return vm.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(homeViewModelProvider);
    final filtersVm = ref.watch(reelFiltersViewModelProvider);
    final entitlementsVm = ref.watch(entitlementsViewModelProvider);
    final entitlements = entitlementsVm.entitlement;
    final entitlementResponse = entitlementsVm.response;
    final isEmptyState = _isEmptyStateVisible(vm);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      // At the top, not the bottom: the shell's own navigation bar sits over
      // the bottom of this screen and was covering it.
      appBar: _isSelecting
          ? PreferredSize(
              preferredSize: Size.fromHeight(AppLayout.of(context).gap(56)),
              child: _SelectionBar(
                count: _selection!.length,
                onCancel: _endSelection,
                onAdd: () => _addSelectionToCollection(vm),
                onDelete: () => _deleteSelection(vm),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            vm.loadReels(forceRefresh: true),
            filtersVm.loadFilters(forceRefresh: true),
          ]),
          color: AppColors.fg(context),
          backgroundColor: AppColors.yellow,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 320) {
                vm.loadMoreReels();
              }
              return false;
            },
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              // Keep roughly a screenful of cards built past each edge. The
              // default 250px drops a row almost as soon as it leaves view, so
              // a small scroll back up rebuilds it from scratch.
              // ignore: deprecated_member_use
              cacheExtent: MediaQuery.sizeOf(context).height,
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.inset(20),
                      layout.gap(20),
                      layout.inset(20),
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'REELPIN',
                              style: GoogleFonts.spaceMono(
                                color: AppColors.fg(context),
                                fontSize: layout.font(
                                  28,
                                  minFactor: 0.9,
                                  maxFactor: 1.08,
                                ),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            _buildSearchButton(context),
                            SizedBox(width: layout.inset(10)),
                            _buildFilterButton(context, vm, filtersVm),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Category Filter Chips ──
                // Nothing saved means nothing to filter, so the row is hidden
                // rather than offering categories that all resolve to empty.
                if (isEmptyState)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        layout.gap(14),
                        layout.inset(20),
                        0,
                      ),
                      child: _buildGuideButton(context),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: layout.gap(56),
                      child: Builder(
                        builder: (context) {
                          // The row refines whatever platform is active, so it
                          // only ever offers categories that exist inside it.
                          final categories = filtersVm
                              .categoriesFor(vm.selectedPlatform)
                              .map((group) => group.category)
                              .toList(growable: false);
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.fromLTRB(
                              layout.inset(20),
                              layout.gap(12),
                              layout.inset(20),
                              layout.gap(4),
                            ),
                            itemCount: categories.length + 1,
                            separatorBuilder: (_, _) =>
                                SizedBox(width: layout.inset(8)),
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return CategoryBadge(
                                  category: 'All',
                                  isSelected: vm.selectedCategory == null,
                                  onTap: () => vm.filterByCategory(null),
                                );
                              }
                              final cat = categories[i - 1];
                              return CategoryBadge(
                                category: cat,
                                isSelected: vm.selectedCategory == cat,
                                onTap: () => vm.filterByCategory(cat),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),

                if (_showFreeHistoryBanner(entitlements))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        0,
                        layout.inset(20),
                        layout.gap(10),
                      ),
                      child: _buildFreePlanBanner(
                        context,
                        entitlementResponse!,
                      ),
                    ),
                  ),

                // ── Content ──
                // Keep restored reels on screen while a refresh runs; the
                // skeleton is only for a genuinely empty first load.
                if (isEmptyState)
                  _buildEmptyState(context)
                else if (vm.error != null && vm.reels.isEmpty)
                  _buildErrorState(context, vm)
                else if (vm.reels.isEmpty)
                  // Covers "loading" and "not started yet" alike — both mean we
                  // cannot show cards and must not claim the library is empty.
                  _buildShimmerGrid(context)
                else ...[
                  _buildReelGrid(context, vm),
                  _buildPaginationState(context, vm),
                ],

                // ── Bottom spacing ──
                // The empty state fills the viewport and carries this clearance
                // in its own padding, so adding it again would make a screen
                // that exactly fits start scrolling.
                if (!isEmptyState)
                  SliverToBoxAdapter(child: SizedBox(height: layout.gap(112))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationState(BuildContext context, HomeViewModel vm) {
    final layout = AppLayout.of(context);
    if (vm.isLoadingMore) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.inset(20),
            layout.gap(16),
            layout.inset(20),
            0,
          ),
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

    if (!vm.hasMoreReels) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.inset(20),
          layout.gap(16),
          layout.inset(20),
          0,
        ),
        child: GestureDetector(
          onTap: vm.loadMoreReels,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: layout.gap(12),
              horizontal: layout.inset(16),
            ),
            decoration: AppTheme.brutalBox(
              context,
              color: AppColors.bg(context),
              shadow: true,
            ),
            alignment: Alignment.center,
            child: Text(
              'LOAD MORE SAVED REELS',
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: layout.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: widget.onSearchTap,
      child: Container(
        width: layout.inset(40),
        height: layout.inset(40),
        decoration: AppTheme.brutalBox(context, shadow: true),
        child: Icon(
          Icons.search,
          color: AppColors.fg(context),
          size: layout.inset(20),
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    HomeViewModel vm,
    ReelFiltersViewModel filtersVm,
  ) {
    final layout = AppLayout.of(context);
    // An active filter is otherwise invisible from the header, which reads as
    // "where did my reels go?" after the sheet closes.
    final isFiltered = vm.hasActiveFilters;
    final accent = _platformAccentColor(vm.selectedPlatform);
    return Semantics(
      button: true,
      label: isFiltered ? 'Filters, active' : 'Filters',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => _showFilterSheet(context, vm, filtersVm),
          child: Container(
            width: layout.inset(40),
            height: layout.inset(40),
            decoration: AppTheme.brutalBox(
              context,
              color: isFiltered ? accent : AppColors.bg(context),
              shadow: true,
            ),
            child: Icon(
              Icons.tune,
              color: isFiltered
                  ? (accent.computeLuminance() > 0.5
                        ? AppColors.black
                        : AppColors.white)
                  : AppColors.fg(context),
              size: layout.inset(20),
            ),
          ),
        ),
      ),
    );
  }

  bool _showFreeHistoryBanner(UserEntitlement? entitlements) {
    return entitlements != null && entitlements.isFree;
  }

  Widget _buildFreePlanBanner(
    BuildContext context,
    EntitlementsResponse entitlements,
  ) {
    final layout = AppLayout.of(context);
    final savedThisMonth = entitlements.usage.reelsSavedThisMonth;
    final monthlyLimit = entitlements.limits.reelsPerMonth;
    final historyDays = entitlements.limits.accessibleHistoryDays;

    return GestureDetector(
      onTap: () => openPaywall(context),
      child: Container(
        decoration: AppTheme.brutalCard(
          context,
          color: const Color(0xFFFFF2B6),
        ),
        child: Padding(
          padding: EdgeInsets.all(layout.inset(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: layout.inset(18),
                height: layout.inset(18),
                margin: EdgeInsets.only(top: layout.gap(2)),
                color: AppColors.yellow,
                child: Icon(
                  Icons.lock_outline,
                  size: layout.inset(12),
                  color: AppColors.black,
                ),
              ),
              SizedBox(width: layout.inset(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      historyDays == null
                          ? 'FREE ACCOUNT ACCESS'
                          : 'SHOWING LAST $historyDays DAYS ON FREE',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.black,
                        fontSize: layout.font(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: layout.gap(6)),
                    Text(
                      monthlyLimit == null
                          ? '$savedThisMonth SAVES USED THIS MONTH. TAP TO SEE PLANS.'
                          : '$savedThisMonth / $monthlyLimit SAVES USED THIS MONTH. TAP TO SEE PLANS.',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.black,
                        fontSize: layout.font(10),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Grid ──
  Widget _buildReelGrid(BuildContext context, HomeViewModel vm) {
    final layout = AppLayout.of(context);
    final columns = layout.gridColumns(compact: 2, regular: 2, wide: 3);
    final spacing = layout.inset(12);
    final horizontalPadding = layout.inset(14);
    final aspect = layout.gridAspect(
      compact: 0.74,
      regular: 0.80,
      wide: 0.88,
      tablet: 0.92,
    );

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        layout.gap(12),
        horizontalPadding,
        0,
      ),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspect,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final reel = vm.reels[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: columns,
              duration: const Duration(milliseconds: 300),
              child: ScaleAnimation(
                scale: 0.96,
                child: FadeInAnimation(
                  child: ReelCard(
                    reel: reel,
                    selected: _selection?.contains(reel.id),
                    onTap: () {
                      if (_isSelecting) {
                        _toggleSelection(reel.id);
                        return;
                      }
                      Navigator.push(context, reelDetailSlideRoute(reel));
                    },
                    onDelete: () => vm.deleteReel(reel.id),
                    onLongPress: () => _startSelection(reel.id),
                  ),
                ),
              ),
            );
          }, childCount: vm.reels.length),
        ),
      ),
    );
  }

  // ── Shimmer (brutalist: blocky yellow/black pulse) ──
  Widget _buildShimmerGrid(BuildContext context) {
    final layout = AppLayout.of(context);
    final columns = layout.gridColumns(compact: 2, regular: 2, wide: 3);
    final spacing = layout.inset(12);
    final horizontalPadding = layout.inset(14);
    final aspect = layout.gridAspect(
      compact: 0.74,
      regular: 0.80,
      wide: 0.88,
      tablet: 0.92,
    );

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        layout.gap(12),
        horizontalPadding,
        0,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspect,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => Shimmer.fromColors(
            baseColor: AppColors.yellow.withAlpha(80),
            highlightColor: AppColors.yellow,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg(context),
                border: Border.all(
                  color: AppColors.fg(context),
                  width: AppTheme.borderWidth,
                ),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  // ── Empty ──
  Widget _buildEmptyState(BuildContext context) {
    final layout = AppLayout.of(context);
    // Fills the rest of the viewport so the content can reach the bottom of the
    // screen instead of stacking at the top over a screenful of dead space.
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.inset(20),
          layout.gap(26),
          layout.inset(20),
          // Clears the floating nav bar, which overlays the bottom of the shell.
          layout.gap(96),
        ),
        // Grouped by proximity rather than spread evenly: the headline and its
        // supporting line read as one unit, the flow diagram sits close under
        // them as the explanation, and the single remaining gap pushes the
        // source strip to the bottom. Even spacing made three loose islands.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'NOTHING SAVED YET',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: layout.font(22, minFactor: 0.88, maxFactor: 1.06),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: layout.gap(10)),
            Text(
              'FOUND A POST, REEL, SHORT, OR VIDEO YOU WILL NEED LATER? '
              'SHARE IT TO REELPIN AND IT STAYS HERE, READY TO FIND.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: layout.font(12),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            SizedBox(height: layout.gap(28)),
            _buildEmptyFlow(context),
            const Spacer(),
            _buildFirstSaveHint(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFlow(BuildContext context) {
    final layout = AppLayout.of(context);
    return SizedBox(
      height: layout.gap(116),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _emptyFlowTile(
              context,
              icon: Icons.play_arrow,
              title: 'NEED',
              caption: 'anything',
              color: AppColors.surfaceElevatedColor(context),
              iconColor: AppColors.yellow,
            ),
          ),
          _flowArrow(context),
          Expanded(
            child: _emptyFlowTile(
              context,
              icon: Icons.ios_share,
              title: 'SHARE',
              caption: 'to ReelPin',
              color: AppColors.yellow,
              iconColor: AppColors.black,
              textColor: AppColors.black,
            ),
          ),
          _flowArrow(context),
          Expanded(
            child: _emptyFlowTile(
              context,
              icon: Icons.bookmark,
              title: 'FIND',
              caption: 'it later',
              color: AppColors.surfaceElevatedColor(context),
              iconColor: AppColors.yellow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFlowTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String caption,
    required Color color,
    required Color iconColor,
    Color? textColor,
  }) {
    final layout = AppLayout.of(context);
    final resolvedTextColor = textColor ?? AppColors.fg(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.inset(8),
        vertical: layout.gap(12),
      ),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: AppColors.fg(context),
          width: AppTheme.borderWidth,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: layout.inset(28)),
          SizedBox(height: layout.gap(10)),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: resolvedTextColor,
              fontSize: layout.font(12),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: layout.gap(2)),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: resolvedTextColor.withAlpha(190),
              fontSize: layout.font(10),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowArrow(BuildContext context) {
    final layout = AppLayout.of(context);
    return SizedBox(
      width: layout.inset(20),
      child: Center(
        child: Icon(
          Icons.arrow_forward,
          color: AppColors.yellow,
          size: layout.inset(18),
        ),
      ),
    );
  }

  /// Sits where the category row goes once there is content. Phrased as the
  /// question a stuck user actually asks, rather than a bare "show me how"
  /// that gives no clue what it will show.
  Widget _buildGuideButton(BuildContext context) {
    final layout = AppLayout.of(context);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(howToUseRoute()),
      child: Container(
        decoration: AppTheme.brutalCard(context, color: AppColors.yellow),
        padding: EdgeInsets.symmetric(
          horizontal: layout.inset(14),
          vertical: layout.gap(14),
        ),
        child: Row(
          children: [
            Container(
              width: layout.inset(34),
              height: layout.inset(34),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(
                  color: AppColors.black,
                  width: AppTheme.borderWidth,
                ),
              ),
              child: Icon(
                Icons.question_mark,
                size: layout.font(18),
                color: AppColors.yellow,
              ),
            ),
            SizedBox(width: layout.inset(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW DO I SAVE SOMETHING?',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: layout.gap(3)),
                  Text(
                    'WALK THROUGH IT IN 4 STEPS',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.black,
                      fontSize: layout.font(10.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: layout.inset(8)),
            Icon(
              Icons.arrow_forward,
              size: layout.font(18),
              color: AppColors.black,
            ),
          ],
        ),
      ),
    );
  }

  /// Footnote naming the apps you can share from. Deliberately quiet: the
  /// yellow guide button above is the only call to action on this screen, and a
  /// second yellow block was splitting the emphasis between them.
  Widget _buildFirstSaveHint(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.inset(14),
        vertical: layout.gap(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedColor(context),
        border: Border.all(
          color: AppColors.fg(context),
          width: AppTheme.borderWidth,
        ),
      ),
      // Stacked rather than side by side: six badges plus the caption on one
      // row leaves the text a column too narrow to read on small phones.
      child: Column(
        // The empty-state column hands its non-flex children an unbounded
        // height, so this one has to size to its contents.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spread across the full width rather than bunched at the left, so
          // the six read as one even strip.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final platform in SourcePlatform.all)
                _platformIconBadge(context, platform),
            ],
          ),
          SizedBox(height: layout.gap(10)),
          Text(
            'SHARE FROM ${_supportedPlatformSentence()}',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: layout.font(10.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// "INSTAGRAM, YOUTUBE, ... OR LINKEDIN" — built from the registry so the
  /// caption cannot fall out of step with the badges above it.
  String _supportedPlatformSentence() {
    final labels = SourcePlatform.all
        .map((platform) => platform.label)
        .toList();
    if (labels.length == 1) return labels.single;
    return '${labels.sublist(0, labels.length - 1).join(', ')}, OR ${labels.last}';
  }

  Widget _platformIconBadge(BuildContext context, SourcePlatform platform) {
    final layout = AppLayout.of(context);
    return Semantics(
      label: '${platform.name} source platform',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: layout.inset(24),
          height: layout.inset(24),
          padding: EdgeInsets.all(layout.inset(3)),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.black, width: 1.5),
          ),
          child: Image.asset(platform.assetPath),
        ),
      ),
    );
  }

  // ── Error ──
  Widget _buildErrorState(BuildContext context, HomeViewModel vm) {
    final layout = AppLayout.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.inset(32)),
          child: Container(
            padding: EdgeInsets.all(layout.inset(24)),
            decoration: AppTheme.brutalBox(
              context,
              color: AppColors.bg(context),
              shadow: true,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: layout.inset(48),
                  height: layout.inset(48),
                  decoration: BoxDecoration(
                    color: AppColors.destructive,
                    border: Border.all(color: AppColors.fg(context), width: 2),
                  ),
                  child: const Icon(
                    Icons.cloud_off,
                    size: 24,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: layout.gap(16)),
                Text(
                  'COULD NOT CONNECT',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: layout.font(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: layout.gap(6)),
                Text(
                  vm.error ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
                    fontSize: layout.font(12),
                  ),
                ),
                SizedBox(height: layout.gap(20)),
                GestureDetector(
                  onTap: () => vm.loadReels(forceRefresh: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.inset(24),
                      vertical: layout.gap(12),
                    ),
                    decoration: AppTheme.brutalBox(
                      context,
                      color: AppColors.red,
                      shadow: true,
                    ),
                    child: Text(
                      'RETRY',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: layout.font(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter sheet ──
  //
  // Platform first, then category, then subcategory — each level below the
  // platform optional. The whole facet tree is already in memory, so every
  // selection here resolves without a request; only APPLY hits the network.
  void _showFilterSheet(
    BuildContext context,
    HomeViewModel vm,
    ReelFiltersViewModel filtersVm,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? selectedPlatform = vm.selectedPlatform;
        String? selectedCategory = vm.selectedCategory;
        String? selectedSubcategory = vm.selectedSubcategory;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final layout = AppLayout.of(context);
            final platforms = filtersVm.platforms;

            // A refresh can retire the selected platform (its last reel was
            // deleted). Dropping it here keeps the sheet from applying a filter
            // that resolves to nothing.
            if (selectedPlatform != null &&
                filtersVm.platformNamed(selectedPlatform) == null) {
              selectedPlatform = null;
            }

            final categories = filtersVm.categoriesFor(selectedPlatform);
            ReelCategoryGroup? selectedGroup;
            for (final group in categories) {
              if (group.category == selectedCategory) {
                selectedGroup = group;
                break;
              }
            }
            // Narrowing to a platform can drop the chosen category with it.
            if (selectedCategory != null && selectedGroup == null) {
              selectedCategory = null;
              selectedSubcategory = null;
            }

            final subcategories =
                selectedGroup?.subcategories ?? const <ReelSubcategoryFilter>[];
            if (selectedGroup?.subcategoryNamed(selectedSubcategory) == null) {
              selectedSubcategory = null;
            }

            final previewCount = filtersVm.previewCountFor(
              platform: selectedPlatform,
              category: selectedCategory,
              subcategory: selectedSubcategory,
            );
            final topPlatform = filtersVm.platformNamed(filtersVm.topPlatform);
            final accentColor = _platformAccentColor(selectedPlatform);
            final applyTextColor = accentColor.computeLuminance() > 0.5
                ? AppColors.black
                : AppColors.white;
            final activeFilterLabel = _activeFilterLabel(
              filtersVm: filtersVm,
              platform: selectedPlatform,
              category: selectedCategory,
              subcategory: selectedSubcategory,
            );

            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Container(
                // No border: fg is white in dark mode, which drew a hard
                // white frame around the sheet. Every sheet is frameless.
                decoration: BoxDecoration(color: AppColors.bg(context)),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                color: AppColors.fg(context),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FILTER SAVED REELS',
                                        style: GoogleFonts.spaceMono(
                                          color: AppColors.fg(context),
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Pick a social, then narrow it down by category if you want.',
                                        style: GoogleFonts.spaceMono(
                                          color: AppColors.textSec(context),
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: AppTheme.brutalBox(
                                      context,
                                      color: AppColors.bg(context),
                                      shadow: true,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: AppColors.fg(context),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: filtersVm.isLoading && !filtersVm.hasPlatforms
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildFilterSheetStatus(
                                  context,
                                  label: 'LOADING FILTERS...',
                                ),
                              )
                            : filtersVm.error != null && !filtersVm.hasPlatforms
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildFilterSheetError(
                                  context,
                                  filtersVm,
                                ),
                              )
                            : platforms.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildFilterSheetEmpty(context),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SOCIAL',
                                      style: GoogleFonts.spaceMono(
                                        color: AppColors.textSec(context),
                                        fontSize: layout.font(10),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: layout.gap(10)),
                                    Wrap(
                                      spacing: layout.inset(8),
                                      runSpacing: layout.gap(8),
                                      children: [
                                        _PlatformFilterTile(
                                          platformId: null,
                                          label: 'ALL',
                                          count: filtersVm.totalCount,
                                          isSelected: selectedPlatform == null,
                                          onTap: () => setSheetState(() {
                                            selectedPlatform = null;
                                            selectedCategory = null;
                                            selectedSubcategory = null;
                                          }),
                                        ),
                                        for (final platform in platforms)
                                          _PlatformFilterTile(
                                            platformId: platform.platform,
                                            label: platform.displayLabel,
                                            count: platform.count,
                                            isSelected:
                                                selectedPlatform ==
                                                platform.platform,
                                            onTap: () => setSheetState(() {
                                              // Re-tapping the active social
                                              // clears it rather than trapping
                                              // the user in one platform.
                                              final isActive =
                                                  selectedPlatform ==
                                                  platform.platform;
                                              selectedPlatform = isActive
                                                  ? null
                                                  : platform.platform;
                                              selectedCategory = null;
                                              selectedSubcategory = null;
                                            }),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: layout.gap(20)),
                                    _buildFilterDropdownField(
                                      context,
                                      label: 'CATEGORY',
                                      hint: 'ALL CATEGORIES',
                                      value: selectedCategory,
                                      enabled: categories.isNotEmpty,
                                      accentColor: accentColor,
                                      items: categories
                                          .map(
                                            (item) => _FilterOption(
                                              value: item.category,
                                              label: item.displayLabel,
                                              count: item.count,
                                              accentColor:
                                                  AppColors.getCategoryColor(
                                                    item.category,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setSheetState(() {
                                          selectedCategory = value;
                                          selectedSubcategory = null;
                                        });
                                      },
                                    ),
                                    SizedBox(height: layout.gap(16)),
                                    _buildFilterDropdownField(
                                      context,
                                      label: 'SUBCATEGORY',
                                      hint: selectedCategory == null
                                          ? 'SELECT CATEGORY FIRST'
                                          : 'ALL SUBCATEGORIES',
                                      value: selectedSubcategory,
                                      enabled:
                                          selectedCategory != null &&
                                          subcategories.isNotEmpty,
                                      accentColor: accentColor,
                                      items: subcategories
                                          .map(
                                            (subcategory) => _FilterOption(
                                              value: subcategory.name,
                                              label: subcategory.displayLabel,
                                              count: subcategory.count,
                                              accentColor: accentColor,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setSheetState(() {
                                          selectedSubcategory = value;
                                        });
                                      },
                                    ),
                                    SizedBox(height: layout.gap(12)),
                                    Text(
                                      _filterHint(
                                        platform: selectedPlatform,
                                        category: selectedCategory,
                                        hasSubcategories:
                                            subcategories.isNotEmpty,
                                      ),
                                      style: GoogleFonts.spaceMono(
                                        color: AppColors.textSec(context),
                                        fontSize: 10,
                                        height: 1.5,
                                      ),
                                    ),
                                    SizedBox(height: layout.gap(20)),
                                    _buildCompactFilterSummary(
                                      context,
                                      activeFilterLabel: activeFilterLabel,
                                      previewCount: previewCount,
                                      totalCount: filtersVm.totalCount,
                                      currentAccentColor: accentColor,
                                      topPlatform: topPlatform,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        decoration: BoxDecoration(
                          color: AppColors.bg(context),
                          border: Border(
                            top: BorderSide(
                              color: AppColors.fg(context),
                              width: AppTheme.thinBorderWidth,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    selectedPlatform = null;
                                    selectedCategory = null;
                                    selectedSubcategory = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: AppTheme.brutalBox(
                                    context,
                                    color: AppColors.bg(context),
                                    shadow: true,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'RESET',
                                    style: GoogleFonts.spaceMono(
                                      color: AppColors.fg(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () {
                                  vm.applyFilters(
                                    platform: selectedPlatform,
                                    category: selectedCategory,
                                    subcategory: selectedSubcategory,
                                  );
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: AppTheme.brutalBox(
                                    context,
                                    color: accentColor,
                                    shadow: true,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'APPLY / $previewCount REEL${previewCount == 1 ? '' : 'S'}',
                                    style: GoogleFonts.spaceMono(
                                      color: applyTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// "INSTAGRAM / FOOD / STREET FOOD" — only the levels that are actually set.
  String _activeFilterLabel({
    required ReelFiltersViewModel filtersVm,
    required String? platform,
    required String? category,
    required String? subcategory,
  }) {
    final parts = <String>[
      if (platform != null)
        filtersVm.platformNamed(platform)?.displayLabel ??
            platform.toUpperCase(),
      if (category != null) category.toUpperCase(),
      if (subcategory != null) subcategory.toUpperCase(),
    ];
    return parts.isEmpty ? 'ALL REELS' : parts.join(' / ');
  }

  String _filterHint({
    required String? platform,
    required String? category,
    required bool hasSubcategories,
  }) {
    if (category == null) {
      return platform == null
          ? 'Pick a social to narrow things down, or filter by category alone.'
          : 'Pick a category to narrow this social down further.';
    }
    if (!hasSubcategories) {
      return 'No saved subcategories in this category yet.';
    }
    return 'Choose a saved subcategory for ${category.toLowerCase()}.';
  }

  Widget _buildFilterSheetStatus(
    BuildContext context, {
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.brutalBox(context, shadow: true),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.fg(context),
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSheetError(
    BuildContext context,
    ReelFiltersViewModel filtersVm,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.brutalBox(
        context,
        color: AppColors.bg(context),
        shadow: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COULD NOT LOAD FILTERS',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtersVm.error ?? '',
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => filtersVm.loadFilters(forceRefresh: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: AppTheme.brutalBox(
                context,
                color: AppColors.red,
                shadow: true,
              ),
              child: Text(
                'RETRY',
                style: GoogleFonts.spaceMono(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSheetEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.brutalBox(context, shadow: true),
      child: Text(
        'NO FILTERS YET. SAVE A FEW REELS FIRST, THEN OPEN FILTERS AGAIN.',
        style: GoogleFonts.spaceMono(
          color: AppColors.fg(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCompactFilterSummary(
    BuildContext context, {
    required String activeFilterLabel,
    required int previewCount,
    required int totalCount,
    required Color currentAccentColor,
    required ReelPlatformGroup? topPlatform,
  }) {
    final layout = AppLayout.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildFilterInfoCard(
              context,
              label: 'CURRENT FILTER',
              title: activeFilterLabel,
              subtitle: '$previewCount OF $totalCount REELS',
              accentColor: currentAccentColor,
            ),
          ),
          SizedBox(width: layout.inset(12)),
          Expanded(
            child: _buildFilterInfoCard(
              context,
              label: 'TOP SOCIAL',
              title: topPlatform?.displayLabel ?? 'NONE YET',
              subtitle: topPlatform == null
                  ? 'SAVE REELS TO BUILD FILTERS'
                  : '${topPlatform.count} REELS SAVED',
              accentColor: _platformAccentColor(topPlatform?.platform),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInfoCard(
    BuildContext context, {
    required String label,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    final layout = AppLayout.of(context);
    final accentText = accentColor.computeLuminance() > 0.5
        ? AppColors.black
        : AppColors.white;
    // Only a floor: a filter label can run to two lines ("INSTAGRAM / MOVIES"),
    // and clamping the height to fit one would clip it. The row stretches both
    // cards to the taller of the two, so they still line up.
    return Container(
      constraints: BoxConstraints(minHeight: layout.gap(126)),
      padding: EdgeInsets.all(layout.inset(16)),
      decoration: AppTheme.brutalBox(context, shadow: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: layout.font(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: layout.gap(10)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: layout.inset(10),
              vertical: layout.gap(6),
            ),
            decoration: BoxDecoration(
              color: accentColor,
              border: Border.all(color: AppColors.fg(context), width: 2),
            ),
            child: Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                color: accentText,
                fontSize: layout.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: layout.gap(10)),
          Text(
            subtitle,
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: layout.font(10),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdownField(
    BuildContext context, {
    required String label,
    required String hint,
    required String? value,
    required bool enabled,
    required Color accentColor,
    required List<_FilterOption> items,
    required ValueChanged<String?> onChanged,
  }) {
    final layout = AppLayout.of(context);
    final resolvedAccent = enabled
        ? accentColor
        : AppColors.surfaceElevatedColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: layout.font(10),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: layout.gap(8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: layout.inset(12)),
          decoration: AppTheme.brutalBox(
            context,
            color: enabled
                ? AppColors.bg(context)
                : AppColors.surfaceElevatedColor(context),
            shadow: true,
          ),
          child: Row(
            children: [
              Container(
                width: layout.inset(8),
                height: layout.gap(42),
                color: resolvedAccent,
              ),
              SizedBox(width: layout.inset(12)),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    dropdownColor: AppColors.bg(context),
                    iconEnabledColor: AppColors.fg(context),
                    iconDisabledColor: AppColors.textSec(context),
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                    ),
                    hint: Text(
                      hint,
                      style: GoogleFonts.spaceMono(
                        color: AppColors.textSec(context),
                        fontSize: layout.font(11),
                      ),
                    ),
                    selectedItemBuilder: (_) => items
                        .map(
                          (item) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceMono(
                                color: AppColors.fg(context),
                                fontSize: layout.font(11),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: items
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.value,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: layout.inset(10)),
                                _buildCountBadge(
                                  context,
                                  item.count,
                                  backgroundColor: item.accentColor,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(
    BuildContext context,
    int count, {
    required Color backgroundColor,
  }) {
    final layout = AppLayout.of(context);
    final textColor = backgroundColor.computeLuminance() > 0.5
        ? AppColors.black
        : AppColors.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.inset(8),
        vertical: layout.gap(3),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AppColors.fg(context), width: 1.5),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.spaceMono(
          color: textColor,
          fontSize: layout.font(10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The action bar shown while the grid is in selection mode.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onAdd,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final hasSelection = count > 0;
    return Container(
      color: AppColors.bg(context),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.inset(14),
            layout.gap(10),
            layout.inset(14),
            layout.gap(10),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(layout.inset(6)),
                  child: Icon(
                    Icons.close,
                    color: AppColors.fg(context),
                    size: layout.inset(20),
                  ),
                ),
              ),
              SizedBox(width: layout.inset(8)),
              Expanded(
                child: Text(
                  '$count SELECTED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: layout.font(11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _SelectionAction(
                icon: Icons.drive_file_move,
                label: 'ADD TO COLLECTION',
                color: AppColors.blue,
                iconColor: AppColors.white,
                onTap: hasSelection ? onAdd : null,
              ),
              SizedBox(width: layout.inset(10)),
              _SelectionAction(
                icon: Icons.delete_outline,
                color: AppColors.destructive,
                iconColor: AppColors.white,
                onTap: hasSelection ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  /// When set the button widens to carry the words too, for the action whose
  /// icon alone does not say what it does.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final text = label;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: layout.inset(40),
          width: text == null ? layout.inset(40) : null,
          padding: text == null
              ? null
              : EdgeInsets.symmetric(horizontal: layout.inset(12)),
          alignment: Alignment.center,
          decoration: AppTheme.brutalBox(context, color: color),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: layout.inset(18)),
              if (text != null) ...[
                SizedBox(width: layout.inset(8)),
                Text(
                  text,
                  style: GoogleFonts.spaceMono(
                    color: iconColor,
                    fontSize: layout.font(10),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
