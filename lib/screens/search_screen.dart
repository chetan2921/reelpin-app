import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/category_filters_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';
import '../widgets/search_result_tile.dart';
import 'profile_screen.dart';
import 'reel_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _searchDebounceDelay = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  DateTime? _selectedSavedDate;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child:
            Consumer4<
              SearchViewModel,
              HomeViewModel,
              SessionViewModel,
              CategoryFiltersViewModel
            >(
              builder: (context, vm, homeVm, sessionVm, categoryVm, _) {
                return Column(
                  children: [
                    // ── Header ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        layout.inset(20),
                        layout.gap(20),
                        layout.inset(20),
                        0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'DISCOVER',
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
                          GestureDetector(
                            onTap: () => _pickSavedDate(context, homeVm),
                            child: Container(
                              width: layout.inset(44),
                              height: layout.inset(44),
                              decoration: AppTheme.brutalBox(
                                context,
                                color: _selectedSavedDate != null
                                    ? AppTheme.yellow
                                    : AppTheme.bg(context),
                                shadow: true,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _selectedSavedDate != null
                                    ? Icons.event_available
                                    : Icons.calendar_month,
                                color: _selectedSavedDate != null
                                    ? AppTheme.black
                                    : AppTheme.fg(context),
                                size: layout.inset(20),
                              ),
                            ),
                          ),
                          SizedBox(width: layout.inset(10)),

                          GestureDetector(
                            onTap: () {
                              final homeVm = context.read<HomeViewModel>();
                              final mapVm = context.read<MapViewModel>();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MultiProvider(
                                    providers: [
                                      ChangeNotifierProvider<
                                        HomeViewModel
                                      >.value(value: homeVm),
                                      ChangeNotifierProvider<
                                        MapViewModel
                                      >.value(value: mapVm),
                                    ],
                                    child: const ProfileScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: layout.inset(44),
                              height: layout.inset(44),
                              decoration: AppTheme.brutalBox(
                                context,
                                color: AppTheme.hotPink,
                                shadow: true,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                sessionVm.initials,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.fg(context),
                                  fontSize: layout.font(13),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          if (vm.lastQuery.isNotEmpty) ...[
                            SizedBox(width: layout.inset(12)),
                            GestureDetector(
                              onTap: () {
                                _searchDebounce?.cancel();
                                vm.clear();
                                _controller.clear();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: layout.inset(12),
                                  vertical: layout.gap(8),
                                ),
                                decoration: AppTheme.brutalBox(
                                  context,
                                  color: AppTheme.bg(context),
                                  shadow: true,
                                ),
                                child: Text(
                                  'CLEAR',
                                  style: GoogleFonts.spaceMono(
                                    color: AppTheme.fg(context),
                                    fontSize: layout.font(11),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: layout.gap(16)),

                    // ── Search Input ──
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.inset(20),
                      ),
                      child: Container(
                        decoration: AppTheme.brutalBox(context, shadow: true),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.fg(context),
                            fontSize: layout.font(13),
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: AppTheme.fg(context),
                          decoration: InputDecoration(
                            hintText: 'SEARCH YOUR SAVED REELS...',
                            hintStyle: GoogleFonts.spaceMono(
                              color: AppTheme.textSec(context),
                              fontSize: layout.font(12),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.fg(context),
                              size: layout.inset(22),
                            ),
                            suffixIcon: vm.isSearching
                                ? Padding(
                                    padding: EdgeInsets.all(layout.inset(14)),
                                    child: SizedBox(
                                      width: layout.inset(16),
                                      height: layout.inset(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppTheme.fg(context),
                                      ),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: layout.inset(16),
                              vertical: layout.gap(14),
                            ),
                          ),
                          onChanged: (value) => _handleSearchChanged(vm, value),
                          onSubmitted: (q) => _doSearch(vm, q),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                    ),
                    SizedBox(height: layout.gap(16)),

                    // ── Content ──
                    Expanded(
                      child: vm.isSearching
                          ? _buildSearchingState(context)
                          : vm.error != null
                          ? _buildError(context, vm)
                          : vm.hasResults
                          ? _buildResults(context, vm)
                          : vm.lastQuery.isNotEmpty
                          ? _buildNoResults(context, vm.lastQuery)
                          : _buildDiscoverContent(context, homeVm, categoryVm),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }

  void _handleSearchChanged(SearchViewModel vm, String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      vm.clear();
      return;
    }

    _searchDebounce = Timer(_searchDebounceDelay, () {
      if (!mounted) return;
      vm.search(query);
    });
  }

  void _doSearch(SearchViewModel vm, String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      vm.clear();
      return;
    }
    _focusNode.unfocus();
    vm.search(query);
  }

  Future<void> _pickSavedDate(
    BuildContext context,
    HomeViewModel homeVm,
  ) async {
    final datedReels = homeVm.reels
        .where((reel) => reel.createdAt != null)
        .toList();
    final now = DateTime.now();
    final initialDate = _selectedSavedDate ?? now;

    if (datedReels.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'NO SAVED REELS WITH DATES YET.',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.bg(context),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppTheme.fg(context), width: 2),
          ),
        ),
      );
      return;
    }

    final parsedDates = datedReels
        .map((reel) => DateTime.tryParse(reel.createdAt!)?.toLocal())
        .whereType<DateTime>()
        .toList();
    if (parsedDates.isEmpty) return;

    parsedDates.sort();
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(initialDate, parsedDates.first, now),
      firstDate: parsedDates.first,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.yellow,
              onPrimary: AppTheme.black,
              surface: AppTheme.bg(context),
              onSurface: AppTheme.fg(context),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppTheme.bg(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(
                  color: AppTheme.fg(context),
                  width: AppTheme.borderWidth,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedSavedDate = DateUtils.dateOnly(picked);
    });
  }

  DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
    if (value.isBefore(min)) return min;
    if (value.isAfter(max)) return max;
    return value;
  }

  List _reelsForDate(List reels, DateTime selectedDate) {
    final target = DateUtils.dateOnly(selectedDate);
    return reels.where((reel) {
      final createdAt = reel.createdAt;
      if (createdAt == null) return false;
      final parsed = DateTime.tryParse(createdAt)?.toLocal();
      if (parsed == null) return false;
      return DateUtils.isSameDay(DateUtils.dateOnly(parsed), target);
    }).toList();
  }

  String _formatSelectedDate(DateTime value) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  Widget _buildNoResults(BuildContext context, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          width: double.infinity,
          decoration: AppTheme.brutalCard(context),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: AppTheme.brutalBox(
                    context,
                    color: AppTheme.yellow,
                    shadow: false,
                  ),
                  child: Icon(
                    Icons.search_off,
                    color: AppTheme.fg(context),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NO MATCHES FOUND',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TRY A DIFFERENT PHRASE OR USE A CATEGORY NAME. SEARCH LOOKS THROUGH TITLES, SUMMARIES, TRANSCRIPTS, FACTS, PEOPLE, AND LOCATIONS.\n\nQUERY: ${query.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.textSec(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Discover (no search active) ──
  Widget _buildDiscoverContent(
    BuildContext context,
    HomeViewModel homeVm,
    CategoryFiltersViewModel categoryVm,
  ) {
    final reels = homeVm.reels;
    final dateReels = _selectedSavedDate == null
        ? const []
        : _reelsForDate(reels, _selectedSavedDate!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      children: [
        if (_selectedSavedDate != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SAVED ON ${_formatSelectedDate(_selectedSavedDate!)}',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSavedDate = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: AppTheme.brutalBox(
                      context,
                      color: AppTheme.bg(context),
                      shadow: true,
                    ),
                    child: Text(
                      'CLEAR DATE',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (dateReels.isNotEmpty) ...[
            _buildRecentSaves(context, dateReels),
            const SizedBox(height: 24),
          ] else ...[
            _buildDateEmptyState(context, _selectedSavedDate!),
            const SizedBox(height: 24),
          ],
        ],

        // Quick searches
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            'QUICK SEARCH',
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSec(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildQuickSearches(context),
        const SizedBox(height: 24),

        // Recent saves
        if (_selectedSavedDate == null && reels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'RECENT SAVES',
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
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
                    border: Border.all(color: AppTheme.fg(context), width: 2),
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
          _buildRecentSaves(context, reels),
          const SizedBox(height: 24),
        ],

        // Category browse
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'BROWSE BY CATEGORY',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        _buildCategoryGrid(context, homeVm, categoryVm),

        // Collection summary
        if (reels.isNotEmpty) ...[const SizedBox(height: 24)],
      ],
    );
  }

  Widget _buildDateEmptyState(BuildContext context, DateTime selectedDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: AppTheme.brutalCard(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: AppTheme.brutalBox(
                  context,
                  color: AppTheme.yellow,
                  shadow: false,
                ),
                child: Icon(
                  Icons.event_busy,
                  size: 22,
                  color: AppTheme.fg(context),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'NO REELS SAVED ON ${_formatSelectedDate(selectedDate)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSearches(BuildContext context) {
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
              decoration: AppTheme.brutalBox(context, shadow: true),
              child: Center(
                child: Text(
                  prompts[i].toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.fg(context),
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

  Widget _buildRecentSaves(BuildContext context, List reels) {
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
                MaterialPageRoute(
                  builder: (_) =>
                      ReelDetailScreen.withProviders(context, reel: reel),
                ),
              );
            },
            child: Container(
              width: 190,
              decoration: AppTheme.brutalBox(context, shadow: true),

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
                                color: AppTheme.fg(context),
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
                                color: AppTheme.fg(context),
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
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.fg(context),
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

  Widget _buildCategoryGrid(
    BuildContext context,
    HomeViewModel homeVm,
    CategoryFiltersViewModel categoryVm,
  ) {
    final categories = categoryVm.categories;

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
            final count = homeVm.reels.where((r) => r.category == cat).length;
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
                      decoration: AppTheme.brutalCard(context),
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
                                      color: AppTheme.fg(context),
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
                                        color: AppTheme.fg(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$count REEL${count == 1 ? '' : 'S'}',
                                      style: GoogleFonts.spaceMono(
                                        color: AppTheme.fg(context),
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

  // ── Searching state ──
  Widget _buildSearchingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: AppTheme.brutalBox(
              context,
              color: AppTheme.yellow,
              shadow: true,
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.fg(context),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SEARCHING YOUR REELS...',
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ──
  Widget _buildResults(BuildContext context, SearchViewModel vm) {
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
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                    child: Text(
                      '${vm.results.length}',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RESULT${vm.results.length == 1 ? '' : 'S'} FOR "${vm.lastQuery.toUpperCase()}"',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSec(context),
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
  Widget _buildError(BuildContext context, SearchViewModel vm) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.brutalBox(
          context,
          color: AppTheme.bg(context),
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
                border: Border.all(color: AppTheme.fg(context), width: 2),
              ),
              child: Icon(
                Icons.error_outline,
                size: 22,
                color: AppTheme.bg(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SEARCH FAILED',
              style: GoogleFonts.spaceMono(
                color: AppTheme.fg(context),
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
