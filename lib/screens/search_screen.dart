import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/category_badge.dart';
import '../widgets/search_result_tile.dart';

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
      backgroundColor: AppTheme.midnightPlum,
      body: SafeArea(
        bottom: false,
        child: Consumer<SearchViewModel>(
          builder: (context, vm, _) {
            return Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.manage_search_rounded,
                              color: AppTheme.cream,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppTheme.warmGradient.createShader(bounds),
                            child: const Text(
                              'Search Reels',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: AppTheme.cream,
                              ),
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
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepIndigo.withAlpha(180),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.cream.withAlpha(15),
                                  ),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: AppTheme.dustyRose,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Search your saved reels with natural language',
                        style: TextStyle(
                          color: AppTheme.dustyRose.withAlpha(140),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Search Input ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(color: AppTheme.cream),
                    decoration: InputDecoration(
                      hintText: 'e.g. "restaurants in Bangalore"',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.cream.withAlpha(60),
                      ),
                      suffixIcon: vm.isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.dustyRose,
                                ),
                              ),
                            )
                          : null,
                    ),
                    onSubmitted: (q) => _doSearch(vm, q),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Category filter ──
                SizedBox(
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
                const SizedBox(height: 16),

                // ── Results ──
                Expanded(
                  child: vm.isSearching
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  color: AppTheme.dustyRose,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Searching your knowledge base...',
                                style: TextStyle(
                                  color: AppTheme.cream.withAlpha(120),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : vm.error != null
                      ? _buildError(vm)
                      : vm.hasResults
                      ? _buildResults(vm)
                      : _buildPrompt(vm),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _doSearch(SearchViewModel vm, String query) {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();
    vm.search(query);
  }

  Widget _buildResults(SearchViewModel vm) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      itemCount: vm.results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${vm.results.length} result${vm.results.length == 1 ? '' : 's'} for "${vm.lastQuery}"',
              style: TextStyle(
                color: AppTheme.cream.withAlpha(90),
                fontSize: 12,
              ),
            ),
          );
        }
        return SearchResultTile(result: vm.results[i - 1]);
      },
    );
  }

  Widget _buildPrompt(SearchViewModel vm) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.amethyst.withAlpha(80),
                  AppTheme.mauve.withAlpha(50),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.cream.withAlpha(15)),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppTheme.dustyRose.withAlpha(200),
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            vm.lastQuery.isEmpty
                ? 'Ask anything about your reels'
                : 'No results found',
            style: TextStyle(
              color: AppTheme.cream.withAlpha(200),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vm.lastQuery.isEmpty
                ? '"Show me gym exercises for shoulders"'
                : 'Try a different search query',
            style: TextStyle(
              color: AppTheme.dustyRose.withAlpha(100),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(SearchViewModel vm) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: AppTheme.cream.withAlpha(80),
          ),
          const SizedBox(height: 12),
          Text(
            'Search failed',
            style: TextStyle(
              color: AppTheme.cream.withAlpha(200),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vm.error ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.cream.withAlpha(80), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
