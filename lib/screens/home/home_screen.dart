import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'package:reelpin/data_models/reels/reel_category_filters.dart';
import 'package:reelpin/data_models/account/user_entitlement.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/source_platforms.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/view_models/category_filters_view_model.dart';
import 'package:reelpin/view_models/home_view_model.dart';
import 'package:reelpin/components/reels/category_badge.dart';
import 'package:reelpin/components/reels/reel_card.dart';

part 'partials/filter_option.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onSearchTap, this.scrollController});

  final VoidCallback? onSearchTap;
  final ScrollController? scrollController;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _didRequestInitialLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRequestInitialLoad) return;
      _didRequestInitialLoad = true;
      final vm = ref.read(homeViewModelProvider);
      final categoryVm = ref.read(categoryFiltersViewModelProvider);
      // Always revalidate, even when restored content is already on screen —
      // both calls no-op while a load is already in flight.
      if (!vm.isLoading) {
        vm.loadReels(forceRefresh: true);
      }
      if (!categoryVm.isLoading) {
        categoryVm.loadCategoryFilters(forceRefresh: true);
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
    final categoryVm = ref.watch(categoryFiltersViewModelProvider);
    final entitlementsVm = ref.watch(entitlementsViewModelProvider);
    final entitlements = entitlementsVm.entitlement;
    final entitlementResponse = entitlementsVm.response;
    final isEmptyState = _isEmptyStateVisible(vm);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            vm.loadReels(forceRefresh: true),
            categoryVm.loadCategoryFilters(forceRefresh: true),
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
              scrollCacheExtent: MediaQuery.sizeOf(context).height,
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
                            _buildFilterButton(context, vm, categoryVm),
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
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.fromLTRB(
                          layout.inset(20),
                          layout.gap(12),
                          layout.inset(20),
                          layout.gap(4),
                        ),
                        itemCount: categoryVm.categories.length + 1,
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
                          final cat = categoryVm.categories[i - 1];
                          return CategoryBadge(
                            category: cat,
                            isSelected: vm.selectedCategory == cat,
                            onTap: () => vm.filterByCategory(cat),
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
    CategoryFiltersViewModel categoryVm,
  ) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: () => _showFilterSheet(context, vm, categoryVm),
      child: Container(
        width: layout.inset(40),
        height: layout.inset(40),
        decoration: AppTheme.brutalBox(context, shadow: true),
        child: Icon(
          Icons.tune,
          color: AppColors.fg(context),
          size: layout.inset(20),
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
                    onTap: () {
                      Navigator.push(context, reelDetailSlideRoute(reel));
                    },
                    onDelete: () => vm.deleteReel(reel.id),
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
              fontSize: layout.font(9),
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
          Wrap(
            spacing: layout.inset(5),
            runSpacing: layout.inset(5),
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
  void _showFilterSheet(
    BuildContext context,
    HomeViewModel vm,
    CategoryFiltersViewModel categoryVm,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? selectedCategory = vm.selectedCategory;
        String? selectedSubcategory = vm.selectedSubcategory;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categoryItems = categoryVm.groups;
            ReelCategoryGroup? topCategory;
            for (final item in categoryItems) {
              if (item.category == categoryVm.topCategory) {
                topCategory = item;
                break;
              }
            }
            topCategory ??= categoryItems.isNotEmpty
                ? categoryItems.first
                : null;

            ReelCategoryGroup? selectedItem;
            for (final item in categoryItems) {
              if (item.category == selectedCategory) {
                selectedItem = item;
                break;
              }
            }

            final subcategories = selectedItem?.subcategories ?? const [];
            if (selectedSubcategory != null &&
                !subcategories.any(
                  (item) => item.name == selectedSubcategory,
                )) {
              selectedSubcategory = null;
            }

            final previewCount = _previewCountForFilter(
              categoryVm: categoryVm,
              selectedCategory: selectedCategory,
              selectedSubcategory: selectedSubcategory,
              selectedItem: selectedItem,
            );
            final activeFilterLabel = selectedSubcategory != null
                ? '$selectedCategory / $selectedSubcategory'
                : selectedCategory ?? 'ALL REELS';
            final topCategoryAccentColor = topCategory != null
                ? AppColors.getCategoryColor(topCategory.category)
                : AppColors.yellow;
            final currentAccentColor = selectedCategory != null
                ? AppColors.getCategoryColor(selectedCategory!)
                : topCategoryAccentColor;
            final applyAccentColor = selectedCategory != null
                ? currentAccentColor
                : AppColors.yellow;
            final applyTextColor = applyAccentColor.computeLuminance() > 0.5
                ? AppColors.black
                : AppColors.white;

            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg(context),
                  border: Border.all(
                    color: AppColors.fg(context),
                    width: AppTheme.borderWidth,
                  ),
                ),
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
                                        'Use the dropdowns to jump straight to the category you want.',
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
                        child: categoryVm.isLoading && !categoryVm.hasGroups
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildFilterSheetStatus(
                                  context,
                                  label: 'LOADING FILTERS...',
                                ),
                              )
                            : categoryVm.error != null &&
                                  !categoryVm.hasGroups &&
                                  categoryItems.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildFilterSheetError(
                                  context,
                                  categoryVm,
                                ),
                              )
                            : categoryItems.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _buildFilterSheetEmpty(context),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFilterDropdownField(
                                      context,
                                      label: 'CATEGORY',
                                      hint: 'ALL CATEGORIES',
                                      value: selectedCategory,
                                      enabled: categoryItems.isNotEmpty,
                                      accentColor: currentAccentColor,
                                      items: categoryItems
                                          .map(
                                            (item) => _FilterOption(
                                              label: item.category,
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
                                    const SizedBox(height: 16),
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
                                      accentColor: currentAccentColor,
                                      items: subcategories
                                          .map(
                                            (subcategory) => _FilterOption(
                                              label: subcategory.name,
                                              count: subcategory.count,
                                              accentColor: currentAccentColor,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setSheetState(() {
                                          selectedSubcategory = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      selectedCategory == null
                                          ? 'Pick a category to unlock subcategory filters.'
                                          : subcategories.isEmpty
                                          ? 'No saved subcategories in this category yet.'
                                          : 'Choose a saved subcategory for ${selectedCategory!.toLowerCase()}.',
                                      style: GoogleFonts.spaceMono(
                                        color: AppColors.textSec(context),
                                        fontSize: 10,
                                        height: 1.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    _buildCompactFilterSummary(
                                      context,
                                      activeFilterLabel: activeFilterLabel,
                                      previewCount: previewCount,
                                      totalCount: categoryVm.totalCount,
                                      currentAccentColor: currentAccentColor,
                                      topCategory: topCategory,
                                      topAccentColor: topCategoryAccentColor,
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
                                    color: applyAccentColor,
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

  int _previewCountForFilter({
    required CategoryFiltersViewModel categoryVm,
    required String? selectedCategory,
    required String? selectedSubcategory,
    required ReelCategoryGroup? selectedItem,
  }) {
    if (selectedCategory == null) {
      return categoryVm.totalCount;
    }

    if (selectedSubcategory != null && selectedItem != null) {
      for (final subcategory in selectedItem.subcategories) {
        if (subcategory.name == selectedSubcategory) {
          return subcategory.count;
        }
      }
    }

    return selectedItem?.count ?? categoryVm.selectedPreviewCount;
  }

  Widget _buildFilterSheetError(
    BuildContext context,
    CategoryFiltersViewModel categoryVm,
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
            categoryVm.error ?? '',
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => categoryVm.loadCategoryFilters(forceRefresh: true),
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
        'NO CATEGORY FILTERS YET. SAVE A FEW REELS FIRST, THEN OPEN FILTERS AGAIN.',
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
    required ReelCategoryGroup? topCategory,
    required Color topAccentColor,
  }) {
    final layout = AppLayout.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            label: 'TOP CATEGORY',
            title: topCategory?.category ?? 'NONE YET',
            subtitle: topCategory == null
                ? 'SAVE REELS TO BUILD FILTERS'
                : '${topCategory.count} REELS SAVED',
            accentColor: topAccentColor,
          ),
        ),
      ],
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
    final fixedHeight = layout.gap(126);
    return Container(
      constraints: BoxConstraints(
        minHeight: fixedHeight,
        maxHeight: fixedHeight,
      ),
      padding: EdgeInsets.all(layout.inset(16)),
      decoration: AppTheme.brutalBox(context, shadow: true),
      child: Column(
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
                              item.label.toUpperCase(),
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
                            value: item.label,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.label.toUpperCase(),
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
          fontSize: layout.font(9),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
