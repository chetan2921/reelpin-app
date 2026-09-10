import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/data_models/discover/discover_response.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/constants/chat_feature.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/view_models/discover_view_model.dart';
import 'package:reelpin/view_models/search_view_model.dart';
import 'package:reelpin/components/reels/reel_card.dart';
import 'package:reelpin/screens/discover/partials/search_result_tile.dart';
import 'package:reelpin/services/analytics/analytics_event.dart';
import 'package:reelpin/services/analytics/analytics_service.dart';

part 'partials/saved_date_calendar_sheet.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.focusRequestId = 0});

  final int focusRequestId;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _searchDebounceDelay = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _searchDebounce;
  int _handledFocusRequestId = 0;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.log(AnalyticsEvent.discoverOpened));
    _controller.addListener(_handleControllerTextChanged);
    _scheduleFocusIfRequested();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(discoverViewModelProvider).loadDiscover());
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.removeListener(_handleControllerTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleFocusIfRequested();
  }

  void _handleControllerTextChanged() {
    final hasSearchText = _controller.text.trim().isNotEmpty;
    if (_hasSearchText == hasSearchText) return;

    setState(() {
      _hasSearchText = hasSearchText;
    });
  }

  void _scheduleFocusIfRequested() {
    final requestId = widget.focusRequestId;
    if (requestId == 0 || _handledFocusRequestId == requestId) return;

    _handledFocusRequestId = requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(searchViewModelProvider);
    final discoverVm = ref.watch(discoverViewModelProvider);
    final sessionVm = ref.watch(sessionViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
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
                  GestureDetector(
                    onTap: () => _pickSavedDate(context),
                    child: Container(
                      width: layout.inset(44),
                      height: layout.inset(44),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: discoverVm.selectedSavedDate != null
                            ? AppColors.yellow
                            : AppColors.bg(context),
                        shadow: true,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        discoverVm.selectedSavedDate != null
                            ? Icons.event_available
                            : Icons.calendar_month,
                        color: discoverVm.selectedSavedDate != null
                            ? AppColors.black
                            : AppColors.fg(context),
                        size: layout.inset(20),
                      ),
                    ),
                  ),
                  SizedBox(width: layout.inset(10)),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, profileRoute());
                    },
                    child: Container(
                      width: layout.inset(44),
                      height: layout.inset(44),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.hotPink,
                        shadow: true,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sessionVm.initials,
                        style: GoogleFonts.spaceMono(
                          color: AppColors.fg(context),
                          fontSize: layout.font(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: layout.gap(16)),

            // ── Search Input ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.inset(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: AppTheme.brutalBox(context, shadow: true),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: layout.font(13),
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: AppColors.fg(context),
                      decoration: InputDecoration(
                        hintText:
                            'SEARCH BY KEYWORD, PLACE, CATEGORY, OR NATURAL LANGUAGE...',
                        hintStyle: GoogleFonts.spaceMono(
                          color: AppColors.textSec(context),
                          fontSize: layout.font(12),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.fg(context),
                          size: layout.inset(22),
                        ),
                        suffixIcon: _buildSearchFieldAction(context, vm),
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
                  SizedBox(height: layout.gap(8)),
                  Text(
                    'TRY: "GOA", "COFFEE", "WEEKEND TRIP", OR "SHOW ME THE GOA BEACH CLUBS WITH SUNSET VIEWS".',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.textSec(context),
                      fontSize: layout.font(10),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  if (chatEnabled && _hasSearchText) ...[
                    SizedBox(height: layout.gap(8)),
                    GestureDetector(
                      onTap: () => openChat(
                        context,
                        ref,
                        seedText: _controller.text.trim(),
                        showAskTab: () =>
                            ref.read(appShellControllerProvider)?.showAsk(),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.fg(context)),
                        ),
                        child: Text(
                          'ASK YOUR SAVES INSTEAD →',
                          style: GoogleFonts.spaceMono(
                            color: AppColors.fg(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
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
                  : vm.isQueryTooShort
                  ? _buildMinimumQueryState(context, vm.lastQuery)
                  : vm.lastQuery.isNotEmpty
                  ? _buildNoResults(context, vm.lastQuery)
                  : _buildDiscoverContent(context, discoverVm),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearchChanged(SearchViewModel vm, String query) {
    _searchDebounce?.cancel();
    ref.read(discoverViewModelProvider).clearCategorySelection();

    if (query.trim().isEmpty) {
      _clearSearch(vm, keepFocus: true);
      return;
    }

    _searchDebounce = Timer(_searchDebounceDelay, () {
      if (!mounted) return;
      vm.search(query);
    });
  }

  void _doSearch(SearchViewModel vm, String query) {
    _searchDebounce?.cancel();
    ref.read(discoverViewModelProvider).clearCategorySelection();
    if (query.trim().isEmpty) {
      _clearSearch(vm, keepFocus: true);
      return;
    }
    _focusNode.unfocus();
    vm.search(query);
  }

  Widget? _buildSearchFieldAction(BuildContext context, SearchViewModel vm) {
    final layout = AppLayout.of(context);
    if (_hasSearchText || vm.lastQuery.isNotEmpty) {
      return IconButton(
        tooltip: 'Clear search',
        onPressed: () => _clearSearch(vm),
        icon: Icon(
          Icons.close,
          color: AppColors.fg(context),
          size: layout.inset(20),
        ),
      );
    }

    if (!vm.isSearching) {
      return null;
    }

    return Padding(
      padding: EdgeInsets.all(layout.inset(14)),
      child: SizedBox(
        width: layout.inset(16),
        height: layout.inset(16),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.fg(context),
        ),
      ),
    );
  }

  void _clearSearch(SearchViewModel vm, {bool keepFocus = false}) {
    _searchDebounce?.cancel();
    if (_controller.text.isNotEmpty) {
      _controller.clear();
    }
    if (!keepFocus) {
      _focusNode.unfocus();
    }
    final discoverVm = ref.read(discoverViewModelProvider);
    if (discoverVm.selectedSavedDate != null || _hasSearchText) {
      setState(() {
        _hasSearchText = false;
      });
    }
    discoverVm.clearTransientSelection();
    vm.clear();
    if (mounted) {
      setState(() {});
    }
  }

  void _clearDateFilter() {
    unawaited(ref.read(discoverViewModelProvider).clearDateFilter());
  }

  Future<void> _openCategory(DiscoverCategory category) async {
    _searchDebounce?.cancel();
    final vm = ref.read(searchViewModelProvider);
    vm.clear();
    if (_controller.text.isNotEmpty) {
      _controller.clear();
    }
    _focusNode.unfocus();
    setState(() {
      _hasSearchText = false;
    });
    await ref.read(discoverViewModelProvider).openCategory(category);
  }

  Future<void> _pickSavedDate(BuildContext context) async {
    final discoverVm = ref.read(discoverViewModelProvider);
    final discover = discoverVm.discover;
    if (discover == null || discover.savedDates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'NO SAVED REELS WITH DATES YET.',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.bg(context),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.fg(context), width: 2),
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<SavedDateOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg(context),
      builder: (context) => _SavedDateCalendarSheet(
        savedDates: discover.savedDates,
        selectedSavedDate: discoverVm.selectedSavedDate,
      ),
    );

    if (selected == null || !mounted) return;
    unawaited(ref.read(discoverViewModelProvider).selectSavedDate(selected));
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
                    color: AppColors.yellow,
                    shadow: false,
                  ),
                  child: Icon(
                    Icons.search_off,
                    color: AppColors.fg(context),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NO MATCHES FOUND',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TRY A DIFFERENT PHRASE OR USE A CATEGORY NAME. SEARCH LOOKS THROUGH TITLES, SUMMARIES, TRANSCRIPTS, FACTS, PEOPLE, AND LOCATIONS.\n\nQUERY: ${query.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
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

  Widget _buildMinimumQueryState(BuildContext context, String query) {
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
                    color: AppColors.yellow,
                    shadow: false,
                  ),
                  child: Icon(
                    Icons.keyboard,
                    color: AppColors.fg(context),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'KEEP TYPING',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ENTER AT LEAST ${SearchViewModel.minimumQueryLength} CHARACTERS BEFORE REELPIN STARTS SEARCHING.\n\nCURRENT: ${query.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
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
    DiscoverViewModel discoverVm,
  ) {
    final discover = discoverVm.discover;
    if (discoverVm.isLoadingDiscover && discover == null) {
      return _buildSearchingState(context);
    }

    if (discoverVm.discoverError != null && discover == null) {
      return _buildDiscoverError(context, discoverVm);
    }

    if (discover == null) {
      return const SizedBox.shrink();
    }

    if (discoverVm.selectedCategory != null) {
      return _buildCategoryReelsContent(context, discoverVm);
    }

    final recentSavesCount = discover.recentSavesCount;

    return NotificationListener<ScrollNotification>(
      onNotification: (_) => false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        children: [
          if (discoverVm.selectedSavedDate != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'SAVED ON ${(discoverVm.selectedSavedDateLabel ?? discoverVm.selectedSavedDate!).toUpperCase()}',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearDateFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.bg(context),
                        shadow: true,
                      ),
                      child: Text(
                        'CLEAR DATE',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.fg(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (discover.reelsForSelectedDate.isNotEmpty) ...[
              _buildRecentSaves(context, discover.reelsForSelectedDate),
              const SizedBox(height: 24),
            ] else ...[
              _buildDateEmptyState(
                context,
                discoverVm.selectedSavedDateLabel ??
                    discoverVm.selectedSavedDate!,
              ),
              const SizedBox(height: 24),
            ],
          ],

          // Quick searches
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              'QUICK SEARCH',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildQuickSearches(context, discover.quickSearchPrompts),
          const SizedBox(height: 24),

          // Recent saves
          if (discoverVm.selectedSavedDate == null &&
              discover.recentSaves.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    'RECENT SAVES',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
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
                      color: AppColors.yellow,
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$recentSavesCount',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildRecentSaves(context, discover.recentSaves),
            const SizedBox(height: 24),
          ],

          // Category browse
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'BROWSE BY CATEGORY',
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          _buildCategoryGrid(context, discover.categoryGrid),
        ],
      ),
    );
  }

  Widget _buildDiscoverError(
    BuildContext context,
    DiscoverViewModel discoverVm,
  ) {
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
                Text(
                  'COULD NOT LOAD DISCOVER',
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  discoverVm.discoverError ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
                    fontSize: 11,
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

  Widget _buildCategoryReelsContent(
    BuildContext context,
    DiscoverViewModel discoverVm,
  ) {
    final page = discoverVm.categoryReelsPage;
    final categoryLabel =
        discoverVm.selectedCategoryLabel ??
        discoverVm.selectedCategory ??
        'CATEGORY';
    final expectedCount =
        discoverVm.selectedCategoryExpectedCount ?? page?.totalCount ?? 0;
    final totalCount = page?.totalCount ?? expectedCount;
    final reels = page?.reels ?? const <Reel>[];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Same reasoning as the home grid: keep a screenful of cards built past
      // each edge so scrolling back does not rebuild them.
      // ignore: deprecated_member_use
      cacheExtent: MediaQuery.sizeOf(context).height,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: AppColors.fg(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalCount REEL${totalCount == 1 ? '' : 'S'}',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.textSec(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ref
                        .read(discoverViewModelProvider)
                        .clearCategorySelection();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: AppTheme.brutalBox(
                      context,
                      color: AppColors.bg(context),
                      shadow: true,
                    ),
                    child: Text(
                      'ALL CATEGORIES',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (discoverVm.isLoadingCategoryReels)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildSearchingState(context),
          )
        else if (discoverVm.categoryReelsError != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildCategoryReelsError(context, discoverVm),
          )
        else if (reels.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildCategoryReelsEmpty(context, categoryLabel),
          )
        else
          _buildCategoryReelGrid(context, reels),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildCategoryReelsError(
    BuildContext context,
    DiscoverViewModel discoverVm,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.brutalBox(
          context,
          color: AppColors.bg(context),
          shadow: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CATEGORY LOAD FAILED',
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              discoverVm.categoryReelsError ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryReelsEmpty(BuildContext context, String categoryLabel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          width: double.infinity,
          decoration: AppTheme.brutalCard(context),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              'NO REELS FOUND IN ${categoryLabel.toUpperCase()}',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryReelGrid(BuildContext context, List<Reel> reels) {
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
      padding: EdgeInsets.symmetric(horizontal: layout.inset(20)),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspect,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final reel = reels[index];
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
                      Navigator.push(context, reelDetailRoute(reel));
                    },
                  ),
                ),
              ),
            );
          }, childCount: reels.length),
        ),
      ),
    );
  }

  Widget _buildDateEmptyState(BuildContext context, String selectedDateLabel) {
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
                  color: AppColors.yellow,
                  shadow: false,
                ),
                child: Icon(
                  Icons.event_busy,
                  size: 22,
                  color: AppColors.fg(context),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'NO REELS SAVED ON ${selectedDateLabel.toUpperCase()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
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

  Widget _buildQuickSearches(BuildContext context, List<String> prompts) {
    if (prompts.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () {
              _controller.text = prompts[i];
              final vm = ref.read(searchViewModelProvider);
              _doSearch(vm, prompts[i]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.brutalBox(context, shadow: true),
              child: Center(
                child: Text(
                  prompts[i].toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppColors.fg(context),
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

  Widget _buildRecentSaves(BuildContext context, List<Reel> reels) {
    final visibleCount = reels.length > 10 ? 10 : reels.length;
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: visibleCount,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final reel = reels[i];
          final catColor = AppColors.getCategoryColor(reel.category);
          return GestureDetector(
            onTap: () {
              Navigator.push(context, reelDetailRoute(reel));
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
                                color: AppColors.fg(context),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              reel.subCategory.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: catColor.computeLuminance() > 0.5
                                    ? AppColors.black
                                    : AppColors.white,
                                fontSize: 10,
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
                                color: AppColors.fg(context),
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
                                  color: AppColors.fg(context),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              reel.relativeDate.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: AppColors.textSecondary,
                                fontSize: 10,
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
    List<DiscoverCategory> categories,
  ) {
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
            final item = categories[i];
            final color = AppColors.getCategoryColor(item.category);

            return AnimationConfiguration.staggeredGrid(
              position: i,
              columnCount: 2,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                verticalOffset: 20,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () => _openCategory(item),
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
                                    item.label.toUpperCase(),
                                    style: GoogleFonts.spaceMono(
                                      color: AppColors.fg(context),
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
                                        color: AppColors.fg(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${item.count} REEL${item.count == 1 ? '' : 'S'}',
                                      style: GoogleFonts.spaceMono(
                                        color: AppColors.fg(context),
                                        fontSize: 10,
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
              color: AppColors.yellow,
              shadow: true,
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.fg(context),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SEARCHING YOUR SAVED REELS...',
            style: GoogleFonts.spaceMono(
              color: AppColors.fg(context),
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
                      color: AppColors.yellow,
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${vm.total}',
                      style: GoogleFonts.spaceMono(
                        color: AppColors.fg(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RESULT${vm.total == 1 ? '' : 'S'} FOR "${vm.lastQuery.toUpperCase()}"',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.textSec(context),
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
          color: AppColors.bg(context),
          shadow: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.destructive,
                border: Border.all(color: AppColors.fg(context), width: 2),
              ),
              child: Icon(
                Icons.error_outline,
                size: 22,
                color: AppColors.bg(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SEARCH FAILED',
              style: GoogleFonts.spaceMono(
                color: AppColors.fg(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              vm.error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
