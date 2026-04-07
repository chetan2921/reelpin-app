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
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: Consumer<HomeViewModel>(
          builder: (context, vm, _) {
            return RefreshIndicator(
              onRefresh: () => vm.loadReels(forceRefresh: true),
              color: AppTheme.black,
              backgroundColor: AppTheme.yellow,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                                  color: AppTheme.black,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.yellow,
                                  border: Border.all(
                                    color: AppTheme.black,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'BETA',
                                  style: GoogleFonts.spaceMono(
                                    color: AppTheme.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
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
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        itemCount: ApiConfig.broadCategories.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                    _buildShimmerGrid()
                  else if (vm.error != null)
                    _buildErrorState(vm)
                  else if (vm.isEmpty)
                    _buildEmptyState()
                  else
                    _buildReelGrid(context, vm),

                  // ── Bottom spacing ──
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, HomeViewModel vm) {
    return GestureDetector(
      onTap: () => _showFilterSheet(context, vm),
      child: Container(
        width: 40,
        height: 40,
        decoration: AppTheme.brutalBox(shadow: true),
        child: const Icon(
          Icons.tune,
          color: AppTheme.black,
          size: 20,
        ),
      ),
    );
  }


  // ── Grid ──
  Widget _buildReelGrid(BuildContext context, HomeViewModel vm) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.80,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final reel = vm.reels[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 2,
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
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOut,
                              )),
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
  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.80,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => Shimmer.fromColors(
            baseColor: AppTheme.yellow.withAlpha(80),
            highlightColor: AppTheme.yellow,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                border: Border.all(
                  color: AppTheme.black,
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
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: AppTheme.brutalBox(color: AppTheme.yellow),
                child: const Icon(
                  Icons.video_library,
                  size: 32,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'NO REELS YET',
                style: GoogleFonts.spaceMono(
                  color: AppTheme.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share a reel from Instagram or TikTok\nto start building your collection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              _buildHowItWorks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.brutalCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          _step('01', 'Find a reel on Instagram or TikTok'),
          const SizedBox(height: 10),
          _step('02', 'Tap share and choose ReelPin'),
          const SizedBox(height: 10),
          _step('03', 'AI extracts all the info and places'),
        ],
      ),
    );
  }

  Widget _step(String num, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.yellow,
            border: Border.all(color: AppTheme.black, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ── Error ──
  Widget _buildErrorState(HomeViewModel vm) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.brutalBox(
              color: AppTheme.white,
              shadow: true,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.destructive,
                    border: Border.all(color: AppTheme.black, width: 2),
                  ),
                  child: const Icon(
                    Icons.cloud_off,
                    size: 24,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'COULD NOT CONNECT',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  vm.error ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => vm.loadReels(forceRefresh: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: AppTheme.brutalBox(
                      color: AppTheme.red,
                      shadow: true,
                    ),
                    child: Text(
                      'RETRY',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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
                color: AppTheme.white,
                border: Border.all(
                  color: AppTheme.black,
                  width: AppTheme.borderWidth,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, color: AppTheme.black),
                  const SizedBox(height: 16),
                  Text(
                    'BROWSE CATEGORIES',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: AppTheme.borderWidth,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: AppTheme.black,
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
                                    color: catColor.computeLuminance() > 0.5 ? AppTheme.black : AppTheme.white,
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
