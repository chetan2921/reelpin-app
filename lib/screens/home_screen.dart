import 'package:flutter/material.dart';
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
      backgroundColor: AppTheme.midnightPlum,
      body: SafeArea(
        bottom: false,
        child: Consumer<HomeViewModel>(
          builder: (context, vm, _) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Hero Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Logo with gradient
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.mauve.withAlpha(60),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.push_pin_rounded,
                                color: AppTheme.cream,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppTheme.warmGradient.createShader(bounds),
                              child: const Text(
                                'ReelPin',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: AppTheme.cream,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _showFilterSheet(context, vm),
                              icon: const Icon(
                                Icons.filter_list_rounded,
                                color: AppTheme.cream,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your AI-powered reel knowledge base',
                          style: TextStyle(
                            color: AppTheme.dustyRose.withAlpha(160),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Category Filter Chips ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
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

                // ── Bottom padding for floating nav ──
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReelGrid(BuildContext context, HomeViewModel vm) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final reel = vm.reels[index];
          return ReelCard(
            reel: reel,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => ReelDetailScreen(reel: reel),
                  transitionsBuilder: (_, anim, _, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOut,
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
          );
        }, childCount: vm.reels.length),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => Shimmer.fromColors(
            baseColor: AppTheme.deepIndigo.withAlpha(160),
            highlightColor: AppTheme.amethyst.withAlpha(100),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.deepIndigo,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.amethyst.withAlpha(80),
                    AppTheme.mauve.withAlpha(50),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.cream.withAlpha(15)),
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 38,
                color: AppTheme.dustyRose.withAlpha(180),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No reels saved yet',
              style: TextStyle(
                color: AppTheme.cream.withAlpha(200),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a reel from Instagram\nto get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.dustyRose.withAlpha(120),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(HomeViewModel vm) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.cream.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not connect to server',
              style: TextStyle(
                color: AppTheme.cream.withAlpha(200),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vm.error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.cream.withAlpha(80),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => vm.loadReels(forceRefresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.mauve.withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 18, color: AppTheme.cream),
                    const SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                color: AppTheme.midnightPlum,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: AppTheme.cream.withAlpha(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.cream.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Categories',
                    style: TextStyle(
                      color: AppTheme.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: ApiConfig.broadCategories.length,
                      itemBuilder: (context, i) {
                        final broadCat = ApiConfig.broadCategories[i];
                        final subCats = ApiConfig.categoryGroups[broadCat]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 16,
                                top: 24,
                              ),
                              child: Text(
                                broadCat,
                                style: TextStyle(
                                  color: AppTheme.cream,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: subCats.map((cat) {
                                return CategoryBadge(
                                  category: cat,
                                  customHeight: 38,
                                  customFontSize: 13,
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
