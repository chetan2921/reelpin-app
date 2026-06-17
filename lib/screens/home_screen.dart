import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../models/folder.dart';
import '../models/reel_category_filters.dart';
import '../models/user_entitlement.dart';
import '../providers/app_providers.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/category_filters_viewmodel.dart';
import '../viewmodels/folders_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/category_badge.dart';
import '../widgets/reel_card.dart';
import 'paywall_screen.dart';
import 'reel_detail_screen.dart';

const _profileGreen = Color.fromARGB(255, 2, 50, 46);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onSearchTap,
    this.isActive = true,
    this.folderSelectionRequestId = 0,
  });

  final VoidCallback? onSearchTap;
  final bool isActive;
  final int folderSelectionRequestId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _backScrollTopThreshold = 32.0;

  final _scrollController = ScrollController();
  bool _didRequestInitialLoad = false;
  bool _isSelectionMode = false;
  bool _isAwayFromTop = false;
  int _handledFolderSelectionRequestId = 0;
  final Set<String> _selectedReelIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRequestInitialLoad) return;
      _didRequestInitialLoad = true;
      final vm = ref.read(homeViewModelProvider);
      final categoryVm = ref.read(categoryFiltersViewModelProvider);
      if (vm.reels.isEmpty && !vm.isLoading) {
        vm.loadReels(forceRefresh: true);
      }
      if (!categoryVm.isLoading && !categoryVm.hasGroups) {
        categoryVm.loadCategoryFilters(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;
    final isAwayFromTop = _scrollController.offset > _backScrollTopThreshold;
    if (isAwayFromTop == _isAwayFromTop || !mounted) return;
    setState(() {
      _isAwayFromTop = isAwayFromTop;
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startFolderSelectionIfRequested();
  }

  void _startFolderSelectionIfRequested() {
    final requestId = widget.folderSelectionRequestId;
    if (requestId == 0 || _handledFolderSelectionRequestId == requestId) return;
    _handledFolderSelectionRequestId = requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToTop();
      setState(() {
        _isSelectionMode = true;
        _selectedReelIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SELECT REELS TO MAKE A FOLDER.',
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.black,
          duration: const Duration(milliseconds: 1600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(homeViewModelProvider);
    final categoryVm = ref.watch(categoryFiltersViewModelProvider);
    final entitlementsVm = ref.watch(entitlementsViewModelProvider);
    final entitlements = entitlementsVm.entitlement;
    final entitlementResponse = entitlementsVm.response;

    return PopScope(
      canPop:
          !widget.isActive ||
          (!_isSelectionMode && _selectedReelIds.isEmpty && !_isAwayFromTop),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !widget.isActive) return;
        if (_isSelectionMode || _selectedReelIds.isNotEmpty) {
          _clearSelection();
          return;
        }
        if (_isAwayFromTop) {
          _scrollToTop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: () => Future.wait([
                  vm.loadReels(forceRefresh: true),
                  categoryVm.loadCategoryFilters(forceRefresh: true),
                ]),
                color: AppTheme.fg(context),
                backgroundColor: AppTheme.yellow,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 320) {
                      vm.loadMoreReels();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                      color: AppTheme.fg(context),
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
                      if (vm.isLoading)
                        _buildShimmerGrid(context)
                      else if (vm.error != null)
                        _buildErrorState(context, vm)
                      else if (vm.isEmpty)
                        _buildEmptyState(context)
                      else ...[
                        _buildReelGrid(context, vm),
                        _buildPaginationState(context, vm),
                      ],

                      // ── Bottom spacing ──
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: layout.gap(_isSelectionMode ? 176 : 96),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSelectionMode)
              Positioned(
                left: layout.inset(20),
                right: layout.inset(20),
                bottom: layout.gap(12),
                child: _buildSelectionBar(context),
              ),
          ],
        ),
      ),
    );
  }

  void _enterSelectionMode(String reelId) {
    setState(() {
      _isSelectionMode = true;
      _selectedReelIds
        ..clear()
        ..add(reelId);
    });
  }

  void _toggleReelSelection(String reelId) {
    setState(() {
      if (_selectedReelIds.contains(reelId)) {
        _selectedReelIds.remove(reelId);
      } else {
        _selectedReelIds.add(reelId);
      }
      if (_selectedReelIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _clearSelection() {
    if (!_isSelectionMode && _selectedReelIds.isEmpty) return;
    setState(() {
      _isSelectionMode = false;
      _selectedReelIds.clear();
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showCreateFolderSheet(
    BuildContext context,
    List<String> reelIds,
  ) async {
    if (reelIds.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final successMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FolderActionSheet(reelIds: reelIds),
    );

    if (successMessage != null && mounted) {
      _clearSelection();
      await ref
          .read(discoverViewModelProvider)
          .loadDiscover(forceRefresh: true);
      ref.read(foldersViewModelProvider).loadFolders();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.yellow,
          duration: const Duration(milliseconds: 1800),
        ),
      );
    }
  }

  Widget _buildSelectionBar(BuildContext context) {
    final layout = AppLayout.of(context);
    final selectedCount = _selectedReelIds.length;
    return Container(
      padding: EdgeInsets.all(layout.inset(12)),
      decoration: AppTheme.brutalBox(
        context,
        color: AppTheme.black,
        shadow: true,
      ),
      child: Row(
        children: [
          Container(
            width: layout.inset(34),
            height: layout.inset(34),
            decoration: BoxDecoration(
              color: AppTheme.yellow,
              border: Border.all(color: AppTheme.white, width: 2),
            ),
            child: Icon(
              Icons.check,
              color: AppTheme.black,
              size: layout.inset(18),
            ),
          ),
          SizedBox(width: layout.inset(10)),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                '$selectedCount SELECTED',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
                  fontSize: layout.font(13),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
              ),
            ),
          ),
          SizedBox(width: layout.inset(10)),
          GestureDetector(
            onTap: _clearSelection,
            child: Container(
              width: layout.inset(36),
              height: layout.inset(36),
              decoration: BoxDecoration(
                color: AppTheme.destructive,
                border: Border.all(color: AppTheme.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.black,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                color: AppTheme.white,
                size: layout.inset(20),
              ),
            ),
          ),
          SizedBox(width: layout.inset(10)),
          GestureDetector(
            onTap: selectedCount == 0
                ? null
                : () => _showCreateFolderSheet(
                    context,
                    _selectedReelIds.toList(growable: false),
                  ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: layout.inset(12),
                vertical: layout.gap(8),
              ),
              decoration: BoxDecoration(
                color: AppTheme.blue,
                border: Border.all(color: AppTheme.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.black,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                'ADD TO FOLDER',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
                  fontSize: layout.font(10),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
                color: AppTheme.fg(context),
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
              color: AppTheme.bg(context),
              shadow: true,
            ),
            alignment: Alignment.center,
            child: Text(
              'LOAD MORE SAVED REELS',
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
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
          color: AppTheme.fg(context),
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
          color: AppTheme.fg(context),
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
                color: AppTheme.yellow,
                child: Icon(
                  Icons.lock_outline,
                  size: layout.inset(12),
                  color: AppTheme.black,
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
                        color: AppTheme.black,
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
                        color: AppTheme.black,
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
            final isSelected = _selectedReelIds.contains(reel.id);
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
                      if (_isSelectionMode) {
                        _toggleReelSelection(reel.id);
                        return;
                      }
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) =>
                              ReelDetailScreen(reel: reel),
                          transitionsBuilder: (_, anim, _, child) {
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: anim,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                    onLongPress: () => _enterSelectionMode(reel.id),
                    onDelete: () => vm.deleteReel(reel.id),
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected,
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
            baseColor: AppTheme.yellow.withAlpha(80),
            highlightColor: AppTheme.yellow,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                border: Border.all(
                  color: AppTheme.fg(context),
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
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.inset(32)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: layout.inset(72),
                height: layout.inset(72),
                decoration: AppTheme.brutalBox(context, color: AppTheme.yellow),
                child: Icon(
                  Icons.video_library,
                  size: layout.inset(32),
                  color: AppTheme.fg(context),
                ),
              ),
              SizedBox(height: layout.gap(20)),
              Text(
                'NO REELS YET',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(20),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: layout.gap(8)),
              Text(
                'Share a reel from Instagram or TikTok\nto start building your collection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSec(context),
                  fontSize: layout.font(12),
                  height: 1.6,
                ),
              ),
              SizedBox(height: layout.gap(28)),
              _buildHowItWorks(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.all(layout.inset(16)),
      decoration: AppTheme.brutalCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: layout.font(13),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: layout.gap(14)),
          _step(context, '01', 'Find a reel on Instagram or TikTok'),
          SizedBox(height: layout.gap(10)),
          _step(context, '02', 'Tap share and choose ReelPin'),
          SizedBox(height: layout.gap(10)),
          _step(context, '03', 'AI extracts all the info and places'),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, String num, String text) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        Container(
          width: layout.inset(28),
          height: layout.inset(28),
          decoration: BoxDecoration(
            color: AppTheme.yellow,
            border: Border.all(color: AppTheme.fg(context), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: layout.font(11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: layout.inset(10)),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSec(context),
              fontSize: layout.font(12),
            ),
          ),
        ),
      ],
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
              color: AppTheme.bg(context),
              shadow: true,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: layout.inset(48),
                  height: layout.inset(48),
                  decoration: BoxDecoration(
                    color: AppTheme.destructive,
                    border: Border.all(color: AppTheme.fg(context), width: 2),
                  ),
                  child: const Icon(
                    Icons.cloud_off,
                    size: 24,
                    color: AppTheme.white,
                  ),
                ),
                SizedBox(height: layout.gap(16)),
                Text(
                  'COULD NOT CONNECT',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
                    fontSize: layout.font(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: layout.gap(6)),
                Text(
                  vm.error ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.textSec(context),
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
                      color: AppTheme.red,
                      shadow: true,
                    ),
                    child: Text(
                      'RETRY',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.white,
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
                ? AppTheme.getCategoryColor(topCategory.category)
                : AppTheme.yellow;
            final currentAccentColor = selectedCategory != null
                ? AppTheme.getCategoryColor(selectedCategory!)
                : topCategoryAccentColor;
            final applyAccentColor = selectedCategory != null
                ? currentAccentColor
                : AppTheme.yellow;
            final applyTextColor = applyAccentColor.computeLuminance() > 0.5
                ? AppTheme.black
                : AppTheme.white;

            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg(context),
                  border: Border.all(
                    color: AppTheme.fg(context),
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
                                color: AppTheme.fg(context),
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
                                          color: AppTheme.fg(context),
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Use the dropdowns to jump straight to the category you want.',
                                        style: GoogleFonts.spaceMono(
                                          color: AppTheme.textSec(context),
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
                                      color: AppTheme.bg(context),
                                      shadow: true,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: AppTheme.fg(context),
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
                                                  AppTheme.getCategoryColor(
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
                                        color: AppTheme.textSec(context),
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
                          color: AppTheme.bg(context),
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.fg(context),
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
                                    color: AppTheme.bg(context),
                                    shadow: true,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'RESET',
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.fg(context),
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
              color: AppTheme.fg(context),
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
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
        color: AppTheme.bg(context),
        shadow: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COULD NOT LOAD FILTERS',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            categoryVm.error ?? '',
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSec(context),
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
                color: AppTheme.red,
                shadow: true,
              ),
              child: Text(
                'RETRY',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.white,
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
          color: AppTheme.fg(context),
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
        ? AppTheme.black
        : AppTheme.white;
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
              color: AppTheme.textSec(context),
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
              border: Border.all(color: AppTheme.fg(context), width: 2),
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
              color: AppTheme.textSec(context),
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
        : AppTheme.surfaceElevatedColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSec(context),
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
                ? AppTheme.bg(context)
                : AppTheme.surfaceElevatedColor(context),
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
                    dropdownColor: AppTheme.bg(context),
                    iconEnabledColor: AppTheme.fg(context),
                    iconDisabledColor: AppTheme.textSec(context),
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                    ),
                    hint: Text(
                      hint,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.textSec(context),
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
                                color: AppTheme.fg(context),
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
        ? AppTheme.black
        : AppTheme.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.inset(8),
        vertical: layout.gap(3),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AppTheme.fg(context), width: 1.5),
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

class _FilterOption {
  final String label;
  final int count;
  final Color accentColor;

  const _FilterOption({
    required this.label,
    required this.count,
    required this.accentColor,
  });
}

class _FolderActionNoteClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 5, size.height - 8)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height + 4,
        0,
        size.height - 4,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FolderActionSheet extends ConsumerStatefulWidget {
  const _FolderActionSheet({required this.reelIds});

  final List<String> reelIds;

  @override
  ConsumerState<_FolderActionSheet> createState() => _FolderActionSheetState();
}

class _FolderActionSheetState extends ConsumerState<_FolderActionSheet> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isCreateMode = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onDraftChanged);
    _noteController.addListener(_onDraftChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final foldersVm = ref.read(foldersViewModelProvider);
      if (foldersVm.folders.isEmpty && !foldersVm.isLoadingFolders) {
        foldersVm.loadFolders();
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onDraftChanged);
    _noteController.removeListener(_onDraftChanged);
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (_isCreateMode && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final foldersVm = ref.watch(foldersViewModelProvider);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = math.max(
      0.0,
      mediaQuery.size.height - bottomInset - layout.gap(28),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  Row(
                    children: [
                      _buildSheetFolderPreview(
                        context,
                        name: '',
                        note: '',
                        reelCount: widget.reelIds.length,
                        accent: _profileGreen,
                        compact: true,
                        showBadge: false,
                      ),
                      SizedBox(width: layout.inset(10)),
                      Expanded(
                        child: Text(
                          'ADD TO FOLDER',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.fg(context),
                            fontSize: layout.font(17),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isSaving ? null : () => Navigator.pop(context),
                        child: Container(
                          width: layout.inset(36),
                          height: layout.inset(36),
                          decoration: AppTheme.brutalBox(
                            context,
                            color: AppTheme.bg(context),
                            shadow: true,
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppTheme.fg(context),
                            size: layout.inset(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: layout.gap(8)),
                  Text(
                    '${widget.reelIds.length} REEL${widget.reelIds.length == 1 ? '' : 'S'} SELECTED',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSec(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: layout.gap(18)),
                  _buildModeSwitch(context),
                  SizedBox(height: layout.gap(16)),
                  if (!_isCreateMode)
                    _buildExistingFolders(context, foldersVm)
                  else ...[
                    _buildField(
                      context,
                      controller: _nameController,
                      label: 'FOLDER NAME',
                      hint: 'GOA TRIP',
                      maxLength: 20,
                      maxLines: 1,
                    ),
                    SizedBox(height: layout.gap(12)),
                    _buildField(
                      context,
                      controller: _noteController,
                      label: 'STICKY NOTE',
                      hint: 'PLACES TO CHECK FIRST',
                      maxLength: 80,
                      maxLines: 3,
                    ),
                  ],
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
                  if (_isCreateMode) ...[
                    SizedBox(height: layout.gap(18)),
                    _buildPrimaryAction(
                      context,
                      label: 'CREATE FOLDER',
                      color: AppTheme.blue,
                      onTap: _isSaving ? null : () => _createFolder(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      decoration: AppTheme.brutalBox(context, shadow: false),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              context,
              label: 'EXISTING',
              active: !_isCreateMode,
              color: _profileGreen,
              onTap: () {
                setState(() {
                  _isCreateMode = false;
                  _error = null;
                });
              },
            ),
          ),
          Container(
            width: AppTheme.borderWidth,
            height: layout.gap(42),
            color: AppTheme.fg(context),
          ),
          Expanded(
            child: _modeButton(
              context,
              label: 'NEW FOLDER',
              active: _isCreateMode,
              color: AppTheme.blue,
              onTap: () {
                setState(() {
                  _isCreateMode = true;
                  _error = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    final layout = AppLayout.of(context);
    final activeTextColor = color == _profileGreen
        ? AppTheme.white
        : AppTheme.black;
    return GestureDetector(
      onTap: _isSaving ? null : onTap,
      child: Container(
        height: layout.gap(42),
        color: active ? color : AppTheme.bg(context),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            color: active ? activeTextColor : AppTheme.fg(context),
            fontSize: layout.font(10),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildExistingFolders(
    BuildContext context,
    FoldersViewModel foldersVm,
  ) {
    final layout = AppLayout.of(context);
    if (foldersVm.isLoadingFolders && foldersVm.folders.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: layout.gap(22)),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.fg(context),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (foldersVm.folders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(layout.inset(16)),
        decoration: AppTheme.brutalBox(
          context,
          color: AppTheme.surfaceElevatedColor(context),
          shadow: false,
        ),
        child: Text(
          'NO FOLDERS YET. CREATE YOUR FIRST ONE HERE.',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSec(context),
            fontSize: layout.font(11),
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: layout.gap(300)),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: foldersVm.folders.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: layout.gap(12),
          crossAxisSpacing: layout.inset(12),
          childAspectRatio: 1.22,
        ),
        itemBuilder: (context, index) {
          final folder = foldersVm.folders[index];
          return _buildExistingFolderButton(context, folder, index);
        },
      ),
    );
  }

  Widget _buildExistingFolderButton(
    BuildContext context,
    FolderSummary folder,
    int index,
  ) {
    final layout = AppLayout.of(context);
    final accent = _folderAccentForIndex(index);
    return GestureDetector(
      onTap: _isSaving ? null : () => _addToExistingFolder(folder),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildSheetFolderPreview(
              context,
              name: folder.name,
              note: '',
              reelCount: folder.reelCount,
              accent: accent,
              showBadge: false,
            ),
            if (_isSaving)
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

  Widget _buildFolderCountBadge(
    BuildContext context,
    int reelCount, {
    bool compact = false,
  }) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.inset(compact ? 5 : 6),
        vertical: layout.gap(compact ? 1.5 : 2),
      ),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border.all(color: AppTheme.fg(context), width: 1.5),
        boxShadow: AppTheme.brutalShadowSmall(context),
      ),
      child: Text(
        '$reelCount REEL${reelCount == 1 ? '' : 'S'}',
        style: GoogleFonts.spaceMono(
          color: AppTheme.fg(context),
          fontSize: layout.font(compact ? 6.5 : 7.5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSheetFolderPreview(
    BuildContext context, {
    required String name,
    required String note,
    required int reelCount,
    required Color accent,
    bool compact = false,
    bool showBadge = true,
  }) {
    final width = compact ? 70.0 : 152.0;
    final height = compact ? 48.0 : 112.0;
    final tabWidth = compact ? 31.0 : 70.0;
    final tabHeight = compact ? 10.0 : 22.0;
    final noteHeight = compact ? 0.0 : 42.0;
    final noteText = note.trim();
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: compact ? 7 : 12,
            left: compact ? 5 : 10,
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
            top: compact ? 2 : 4,
            left: compact ? 10 : 18,
            right: compact ? 7 : 16,
            height: compact ? 20 : 38,
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
            top: compact ? 8 : 15,
            left: 0,
            right: compact ? 4 : 7,
            bottom: compact ? 3 : 5,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: tabWidth,
                    height: tabHeight,
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
                  top: compact ? 7 : 16,
                  child: Container(
                    padding: compact
                        ? EdgeInsets.zero
                        : const EdgeInsets.fromLTRB(10, 14, 10, 9),
                    decoration: BoxDecoration(
                      color: accent,
                      border: Border.all(
                        color: AppTheme.fg(context),
                        width: 1.5,
                      ),
                      boxShadow: AppTheme.brutalShadowSmall(context),
                    ),
                    child: compact
                        ? null
                        : Text(
                            name.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
                if (showBadge && !compact)
                  Positioned(
                    top: compact ? -8 : -9,
                    right: compact ? 2 : 4,
                    child: _buildFolderCountBadge(
                      context,
                      reelCount,
                      compact: compact,
                    ),
                  ),
                if (noteText.isNotEmpty && !compact)
                  Positioned(
                    left: compact ? 12 : 20,
                    right: compact ? 8 : 12,
                    bottom: compact ? 7 : 10,
                    child: _buildSmallFolderNote(
                      context,
                      noteText,
                      height: noteHeight,
                      compact: compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFolderNote(
    BuildContext context,
    String note, {
    required double height,
    bool compact = false,
  }) {
    return Transform.rotate(
      angle: -0.025,
      child: ClipPath(
        clipper: _FolderActionNoteClipper(),
        child: Container(
          height: height,
          padding: EdgeInsets.fromLTRB(
            compact ? 6 : 8,
            compact ? 5 : 8,
            compact ? 6 : 8,
            compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEA75),
            border: Border.all(color: AppTheme.fg(context), width: 1.5),
          ),
          child: Text(
            note.toUpperCase(),
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: compact ? 5.8 : 7,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
            maxLines: compact ? 2 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: layout.gap(14)),
        decoration: AppTheme.brutalBox(
          context,
          color: _isSaving ? AppTheme.surfaceElevatedColor(context) : color,
          shadow: true,
        ),
        alignment: Alignment.center,
        child: _isSaving
            ? SizedBox(
                width: layout.inset(18),
                height: layout.inset(18),
                child: CircularProgressIndicator(
                  color: AppTheme.fg(context),
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.black,
                  fontSize: layout.font(13),
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
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
              hintText: hint,
              hintStyle: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontSize: layout.font(12),
              ),
              counterStyle: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontSize: layout.font(9),
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: layout.inset(12),
                vertical: layout.gap(10),
              ),
            ),
            textInputAction: maxLines == 1
                ? TextInputAction.next
                : TextInputAction.done,
          ),
        ),
      ],
    );
  }

  Future<void> _createFolder({bool moveExisting = false}) async {
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
          .createFolder(
            name: name,
            note: note.isEmpty ? null : note,
            reelIds: widget.reelIds,
            moveExisting: moveExisting,
          );
      if (!mounted) return;
      Navigator.pop(
        context,
        '${widget.reelIds.length} REEL${widget.reelIds.length == 1 ? '' : 'S'} SAVED TO ${name.toUpperCase()}.',
      );
    } on FolderConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      final shouldMove = await _confirmMoveExisting(e);
      if (shouldMove == true && mounted) {
        await _createFolder(moveExisting: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = userFacingErrorMessage(
          e,
          fallbackMessage: 'Could not create the folder right now.',
        );
      });
    }
  }

  Future<void> _addToExistingFolder(
    FolderSummary folder, {
    bool moveExisting = false,
  }) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(foldersViewModelProvider)
          .addReelsToFolder(
            folderId: folder.id,
            reelIds: widget.reelIds,
            moveExisting: moveExisting,
          );
      if (!mounted) return;
      Navigator.pop(
        context,
        '${widget.reelIds.length} REEL${widget.reelIds.length == 1 ? '' : 'S'} ADDED TO ${folder.name.toUpperCase()}.',
      );
    } on FolderConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      final shouldMove = await _confirmMoveExisting(e);
      if (shouldMove == true && mounted) {
        await _addToExistingFolder(folder, moveExisting: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = userFacingErrorMessage(
          e,
          fallbackMessage: 'Could not add reels to this folder right now.',
        );
      });
    }
  }

  Future<bool?> _confirmMoveExisting(FolderConflictException error) {
    final conflicts = error.conflicts;
    final count = conflicts.length;
    final folderNames = conflicts
        .map((item) => item.currentFolderName)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .take(3)
        .join(', ');

    return showDialog<bool>(
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
          'MOVE EXISTING REELS?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          folderNames.isEmpty
              ? '$count selected reel${count == 1 ? '' : 's'} already belong${count == 1 ? 's' : ''} to another folder.'
              : '$count selected reel${count == 1 ? '' : 's'} already belong${count == 1 ? 's' : ''} to $folderNames.',
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
                'MOVE THEM',
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
  }
}
