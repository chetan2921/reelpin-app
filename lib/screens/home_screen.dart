import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../models/reel.dart';
import '../models/reel_category_filters.dart';
import '../theme/app_theme.dart';
import '../viewmodels/category_filters_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/category_badge.dart';
import '../widgets/reel_card.dart';
import 'reel_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Consumer2<HomeViewModel, CategoryFiltersViewModel>(
          builder: (context, vm, categoryVm, _) {
            return RefreshIndicator(
              onRefresh: () => Future.wait([
                vm.loadReels(forceRefresh: true),
                categoryVm.loadCategoryFilters(forceRefresh: true),
              ]),
              color: AppTheme.fg(context),
              backgroundColor: AppTheme.yellow,
              child: CustomScrollView(
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

                  // ── Content ──
                  if (vm.isLoading)
                    _buildShimmerGrid(context)
                  else if (vm.error != null)
                    _buildErrorState(context, vm)
                  else if (vm.isEmpty)
                    _buildEmptyState(context)
                  else
                    _buildReelGrid(context, vm),

                  // ── Bottom spacing ──
                  SliverToBoxAdapter(child: SizedBox(height: layout.gap(96))),
                ],
              ),
            );
          },
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

  // ── Grid ──
  Widget _buildReelGrid(BuildContext context, HomeViewModel vm) {
    final layout = AppLayout.of(context);
    final columns = layout.gridColumns(compact: 2, regular: 2, wide: 3);
    final spacing = layout.inset(14);
    final aspect = layout.gridAspect(
      compact: 0.74,
      regular: 0.80,
      wide: 0.88,
      tablet: 0.92,
    );

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        layout.inset(20),
        layout.gap(12),
        layout.inset(20),
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
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) =>
                              ReelDetailScreen.withProviders(
                                context,
                                reel: reel,
                              ),
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
    final spacing = layout.inset(14);
    final aspect = layout.gridAspect(
      compact: 0.74,
      regular: 0.80,
      wide: 0.88,
      tablet: 0.92,
    );

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        layout.inset(20),
        layout.gap(12),
        layout.inset(20),
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
            final categoryItems = _buildCategoryFilterItems(
              vm.allReels,
              categoryVm.groups,
            );
            final topCategory = categoryItems.isNotEmpty
                ? categoryItems.first
                : null;

            _CategoryFilterItem? selectedItem;
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

            final previewCount = _countFilteredReels(
              vm.allReels,
              category: selectedCategory,
              subcategory: selectedSubcategory,
            );
            final activeFilterLabel = selectedSubcategory != null
                ? '$selectedCategory / $selectedSubcategory'
                : selectedCategory ?? 'ALL REELS';
            final usingFallbackFilters =
                categoryVm.groups.isEmpty && categoryItems.isNotEmpty;
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
                                          : '${subcategories.length} subcategor${subcategories.length == 1 ? 'y' : 'ies'} available in ${selectedCategory!.toLowerCase()}.',
                                      style: GoogleFonts.spaceMono(
                                        color: AppTheme.textSec(context),
                                        fontSize: 10,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (usingFallbackFilters) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Using your saved reels to build filters right now.',
                                        style: GoogleFonts.spaceMono(
                                          color: AppTheme.textSec(context),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    _buildCompactFilterSummary(
                                      context,
                                      activeFilterLabel: activeFilterLabel,
                                      previewCount: previewCount,
                                      totalCount: vm.allReels.length,
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
    required _CategoryFilterItem? topCategory,
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

  List<_CategoryFilterItem> _buildCategoryFilterItems(
    List<Reel> reels,
    List<ReelCategoryGroup> groups,
  ) {
    final sourceGroups = groups.isNotEmpty
        ? groups
        : _deriveCategoryGroups(reels);

    final items =
        sourceGroups.map((group) {
          final categoryCount = reels
              .where((reel) => _matchesLabel(reel.category, group.category))
              .length;
          final subcategories =
              group.subcategories.map((subcategory) {
                final count = reels
                    .where(
                      (reel) =>
                          _matchesLabel(reel.category, group.category) &&
                          _matchesLabel(reel.subCategory, subcategory),
                    )
                    .length;
                return _SubcategoryFilterItem(name: subcategory, count: count);
              }).toList()..sort((left, right) {
                final countCompare = right.count.compareTo(left.count);
                if (countCompare != 0) return countCompare;
                return left.name.toLowerCase().compareTo(
                  right.name.toLowerCase(),
                );
              });

          return _CategoryFilterItem(
            category: group.category,
            count: categoryCount,
            subcategories: subcategories,
          );
        }).toList()..sort((left, right) {
          final countCompare = right.count.compareTo(left.count);
          if (countCompare != 0) return countCompare;
          return left.category.toLowerCase().compareTo(
            right.category.toLowerCase(),
          );
        });

    return items;
  }

  List<ReelCategoryGroup> _deriveCategoryGroups(List<Reel> reels) {
    final grouped = <String, Set<String>>{};
    final categoryLabels = <String, String>{};

    for (final reel in reels) {
      final category = reel.category.trim();
      if (category.isEmpty) continue;

      final categoryKey = category.toLowerCase();
      categoryLabels.putIfAbsent(categoryKey, () => category);
      final subcategories = grouped.putIfAbsent(categoryKey, () => <String>{});

      final subcategory = reel.subCategory.trim();
      if (subcategory.isNotEmpty && !_matchesLabel(category, subcategory)) {
        subcategories.add(subcategory);
      }
    }

    final groups =
        grouped.entries.map((entry) {
          final subcategories = entry.value.toList()
            ..sort(
              (left, right) =>
                  left.toLowerCase().compareTo(right.toLowerCase()),
            );
          return ReelCategoryGroup(
            category: categoryLabels[entry.key] ?? entry.key,
            subcategories: subcategories,
          );
        }).toList()..sort(
          (left, right) => left.category.toLowerCase().compareTo(
            right.category.toLowerCase(),
          ),
        );

    return groups;
  }

  int _countFilteredReels(
    List<Reel> reels, {
    String? category,
    String? subcategory,
  }) {
    return reels.where((reel) {
      if (category != null && !_matchesLabel(reel.category, category)) {
        return false;
      }
      if (subcategory != null &&
          !_matchesLabel(reel.subCategory, subcategory)) {
        return false;
      }
      return true;
    }).length;
  }

  bool _matchesLabel(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();
}

class _CategoryFilterItem {
  final String category;
  final int count;
  final List<_SubcategoryFilterItem> subcategories;

  const _CategoryFilterItem({
    required this.category,
    required this.count,
    required this.subcategories,
  });
}

class _SubcategoryFilterItem {
  final String name;
  final int count;

  const _SubcategoryFilterItem({required this.name, required this.count});
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
