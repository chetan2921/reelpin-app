import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/search_result_tile.dart';
import 'reel_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: Consumer2<SearchViewModel, HomeViewModel>(
          builder: (context, vm, homeVm, _) {
            return Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        'DISCOVER',
                        style: GoogleFonts.spaceMono(
                          color: AppTheme.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      if (vm.hasResults)
                        GestureDetector(
                          onTap: () {
                            vm.clear();
                            _controller.clear();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: AppTheme.brutalBox(
                              color: AppTheme.white,
                              shadow: true,
                            ),
                            child: Text(
                              'CLEAR',
                              style: GoogleFonts.spaceMono(
                                color: AppTheme.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Search Input ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: AppTheme.brutalBox(shadow: true),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: AppTheme.black,
                      decoration: InputDecoration(
                        hintText: 'SEARCH YOUR SAVED REELS...',
                        hintStyle: GoogleFonts.spaceMono(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.black,
                          size: 22,
                        ),
                        suffixIcon: vm.isSearching
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.black,
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (q) => _doSearch(vm, q),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Content ──
                Expanded(
                  child: vm.isSearching
                      ? _buildSearchingState()
                      : vm.error != null
                      ? _buildError(vm)
                      : vm.hasResults
                      ? _buildResults(vm)
                      : _buildDiscoverContent(homeVm),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStats(HomeViewModel vm) {
    final total = vm.reels.length;
    final pinned = vm.reels.where((r) => r.hasMapLocations).length;
    final categories = vm.reels.map((r) => r.category).toSet().length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: AppTheme.brutalCard(),
      child: Row(
        children: [
          _statItem('$total', 'SAVED', AppTheme.yellow),
          Container(width: AppTheme.borderWidth, height: 56, color: AppTheme.black),
          _statItem('$pinned', 'PINNED', AppTheme.neonGreen),
          Container(width: AppTheme.borderWidth, height: 56, color: AppTheme.black),
          _statItem('$categories', 'CATEGORIES', AppTheme.cyan),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: accent.withAlpha(40),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _doSearch(SearchViewModel vm, String query) {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();
    vm.search(query);
  }

  // ── Discover (no search active) ──
  Widget _buildDiscoverContent(HomeViewModel homeVm) {
    final reels = homeVm.reels;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      children: [
        // Quick searches
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            'QUICK SEARCH',
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildQuickSearches(),
        const SizedBox(height: 24),

        // Stats Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildStats(homeVm),
        ),
        const SizedBox(height: 24),

        // Recent saves
        if (reels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'RECENT SAVES',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.yellow,
                    border: Border.all(color: AppTheme.black, width: 2),
                  ),
                  child: Text(
                    '${reels.length}',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildRecentSaves(reels),
          const SizedBox(height: 24),
        ],

        // Category browse
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'BROWSE BY CATEGORY',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        _buildCategoryGrid(homeVm),

        // Collection summary
        if (reels.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'COLLECTION SUMMARY',
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          _buildCollectionSummary(homeVm),
        ],
      ],
    );
  }

  Widget _buildQuickSearches() {
    final prompts = [
      'Food spots nearby',
      'Travel destinations',
      'Workout routines',
      'Study tips',
      'Finance advice',
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () {
              _controller.text = prompts[i];
              final vm = context.read<SearchViewModel>();
              _doSearch(vm, prompts[i]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.brutalBox(
                color: AppTheme.white,
                shadow: true,
              ),
              child: Center(
                child: Text(
                  prompts[i].toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: prompts.length,
      ),
    );
  }

  Widget _buildRecentSaves(List reels) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: reels.length > 8 ? 8 : reels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final reel = reels[i];
          final catColor = AppTheme.getCategoryColor(reel.category);
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReelDetailScreen(reel: reel)),
              );
            },
            child: Container(
              width: 190,
              decoration: AppTheme.brutalCard(),
              child: Row(
                children: [
                  // Color accent bar
                  Container(width: 6, color: catColor),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: catColor,
                              border: Border.all(
                                color: AppTheme.black,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              reel.subCategory.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: catColor.computeLuminance() > 0.5
                                    ? AppTheme.black
                                    : AppTheme.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              reel.title.isNotEmpty ? reel.title : 'Untitled',
                              style: GoogleFonts.spaceMono(
                                color: AppTheme.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.black,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              reel.relativeDate.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: AppTheme.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
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
        },
      ),
    );
  }

  Widget _buildCategoryGrid(HomeViewModel homeVm) {
    final categories = ApiConfig.broadCategories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimationLimiter(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
          ),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final cat = categories[i];
            final count = homeVm.reels
                .where(
                  (r) =>
                      r.category == cat ||
                      (ApiConfig.categoryGroups[cat]?.contains(r.category) ??
                          false) ||
                      (ApiConfig.categoryGroups[cat]?.contains(r.subCategory) ??
                          false),
                )
                .length;
            final color = AppTheme.getCategoryColor(cat);

            return AnimationConfiguration.staggeredGrid(
              position: i,
              columnCount: 2,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                verticalOffset: 20,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () {
                      _controller.text = cat;
                      final vm = context.read<SearchViewModel>();
                      _doSearch(vm, cat);
                    },
                    child: Container(
                      decoration: AppTheme.brutalCard(),
                      child: Row(
                        children: [
                          // Color accent bar
                          Container(width: 8, color: color),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cat.split(' & ').first.toUpperCase(),
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withAlpha(60),
                                      border: Border.all(
                                        color: AppTheme.black,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$count REEL${count == 1 ? '' : 'S'}',
                                      style: GoogleFonts.spaceMono(
                                        color: AppTheme.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCollectionSummary(HomeViewModel homeVm) {
    final reels = homeVm.reels;
    final pinned = reels.where((r) => r.hasMapLocations).length;
    final topCat = _getTopCategory(homeVm);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(0),
        decoration: AppTheme.brutalCard(),
        child: Column(
          children: [
            _insightRow(
              Icons.bookmark,
              'TOTAL SAVED',
              '${reels.length}',
              AppTheme.yellow,
            ),
            Container(height: 2, color: AppTheme.black),
            _insightRow(
              Icons.location_on,
              'WITH LOCATIONS',
              '$pinned',
              AppTheme.neonGreen,
            ),
            if (topCat != null) ...[
              Container(height: 2, color: AppTheme.black),
              _insightRow(
                Icons.star,
                'TOP CATEGORY',
                topCat.toUpperCase(),
                AppTheme.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _insightRow(
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accentColor,
              border: Border.all(color: AppTheme.black, width: 1.5),
            ),
            child: Icon(icon, size: 14, color: AppTheme.black),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _getTopCategory(HomeViewModel homeVm) {
    if (homeVm.reels.isEmpty) return null;
    final counts = <String, int>{};
    for (final r in homeVm.reels) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  // ── Searching state ──
  Widget _buildSearchingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: AppTheme.brutalBox(
              color: AppTheme.yellow,
              shadow: true,
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.black,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SEARCHING YOUR REELS...',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ──
  Widget _buildResults(SearchViewModel vm) {
    return AnimationLimiter(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        itemCount: vm.results.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.yellow,
                      border: Border.all(color: AppTheme.black, width: 2),
                    ),
                    child: Text(
                      '${vm.results.length}',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RESULT${vm.results.length == 1 ? '' : 'S'} FOR "${vm.lastQuery.toUpperCase()}"',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }
          return AnimationConfiguration.staggeredList(
            position: i - 1,
            duration: const Duration(milliseconds: 300),
            child: SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(
                child: SearchResultTile(result: vm.results[i - 1]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Error ──
  Widget _buildError(SearchViewModel vm) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.brutalBox(
          color: AppTheme.white,
          shadow: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.destructive,
                border: Border.all(color: AppTheme.black, width: 2),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 22,
                color: AppTheme.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SEARCH FAILED',
              style: GoogleFonts.spaceMono(
                color: AppTheme.black,
                fontSize: 15,
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
          ],
        ),
      ),
    );
  }
}
