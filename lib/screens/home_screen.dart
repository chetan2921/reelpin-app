import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
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
        child: Consumer<HomeViewModel>(
          builder: (context, vm, _) {
            return RefreshIndicator(
              onRefresh: () => vm.loadReels(forceRefresh: true),
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
                              _buildFilterButton(context, vm),
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
                        itemCount: ApiConfig.broadCategories.length + 1,
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
                          final cat = ApiConfig.broadCategories[i - 1];
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

  Widget _buildFilterButton(BuildContext context, HomeViewModel vm) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: () => _showFilterSheet(context, vm),
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
  void _showFilterSheet(BuildContext context, HomeViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                border: Border.all(
                  color: AppTheme.fg(context),
                  width: AppTheme.borderWidth,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, color: AppTheme.fg(context)),
                  const SizedBox(height: 16),
                  Text(
                    'BROWSE CATEGORIES',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: AppTheme.borderWidth,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: AppTheme.fg(context),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: ApiConfig.broadCategories.length,
                      itemBuilder: (context, i) {
                        final broad = ApiConfig.broadCategories[i];
                        final subs = ApiConfig.categoryGroups[broad]!;
                        final catColor = AppTheme.getCategoryColor(broad);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                                top: 20,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                color: catColor,
                                child: Text(
                                  broad.toUpperCase(),
                                  style: GoogleFonts.spaceMono(
                                    color: catColor.computeLuminance() > 0.5
                                        ? AppTheme.black
                                        : AppTheme.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subs.map((cat) {
                                return CategoryBadge(
                                  category: cat,
                                  customHeight: 34,
                                  customFontSize: 10,
                                  isSelected: vm.selectedCategory == cat,
                                  onTap: () {
                                    vm.filterByCategory(cat);
                                    Navigator.pop(context);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
