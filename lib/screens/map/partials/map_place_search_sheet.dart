part of '../map_screen.dart';

class _MapPlaceSearchSheet extends ConsumerStatefulWidget {
  const _MapPlaceSearchSheet({
    required this.onMapItemSelected,
    required this.onMapItemPinned,
  });

  final ValueChanged<MapItem> onMapItemSelected;
  final ValueChanged<MapItem> onMapItemPinned;

  @override
  ConsumerState<_MapPlaceSearchSheet> createState() =>
      _MapPlaceSearchSheetState();
}

class _MapPlaceSearchSheetState extends ConsumerState<_MapPlaceSearchSheet> {
  static const _searchDebounceDelay = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasQuery = false;
  String _lastHandledSearchText = '';
  String _lastSearchedQuery = '';
  String? _savingResultKey;
  _PlaceSearchTab _selectedTab = _PlaceSearchTab.all;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final query = _controller.text.trim();
    final hasQuery = query.isNotEmpty;
    if (_hasQuery != hasQuery) {
      setState(() {
        _hasQuery = hasQuery;
      });
    }

    if (query == _lastHandledSearchText) return;
    _lastHandledSearchText = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDelay, _runSearch);
  }

  void _runSearch({bool force = false}) {
    final query = _controller.text.trim();
    if (query.length < 2) {
      _lastSearchedQuery = '';
      ref.read(mapViewModelProvider).clearPlaceSearch();
      return;
    }

    if (!force && query == _lastSearchedQuery) return;
    _lastSearchedQuery = query;
    unawaited(ref.read(mapViewModelProvider).searchMapPlaces(query));
  }

  Future<void> _handleResultTap(
    MapPlaceSearchResult result,
    String resultKey,
  ) async {
    final existingItem = result.mapItem;
    if (existingItem != null) {
      Navigator.pop(context);
      widget.onMapItemSelected(existingItem);
      return;
    }

    if (!result.canPin) return;
    final googlePlaceId = result.googlePlaceId?.trim();
    if (googlePlaceId == null ||
        googlePlaceId.isEmpty ||
        _savingResultKey != null) {
      return;
    }

    setState(() {
      _savingResultKey = resultKey;
    });

    MapItem? item;
    try {
      item = await ref.read(mapViewModelProvider).pinPlace(result);
    } finally {
      if (mounted) {
        setState(() {
          _savingResultKey = null;
        });
      }
    }

    if (!mounted) return;

    if (item == null) {
      final vm = ref.read(mapViewModelProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.mapPinActionError ?? 'COULD NOT SAVE THIS PIN',
            style: GoogleFonts.spaceMono(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    Navigator.pop(context);
    widget.onMapItemPinned(item);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(mapViewModelProvider);
    final query = _controller.text.trim();
    final showTabs =
        query.length >= 2 &&
        !vm.isSearchingPlaces &&
        vm.placeSearchError == null &&
        vm.placeSearchResults.isNotEmpty;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Material(
        color: AppColors.bg(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.inset(20),
                  layout.gap(16),
                  layout.inset(20),
                  layout.gap(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'SEARCH PLACES',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.fg(context),
                              fontSize: layout.font(
                                20,
                                minFactor: 0.86,
                                maxFactor: 1.05,
                              ),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(width: layout.inset(10)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: layout.inset(40),
                            height: layout.inset(40),
                            decoration: AppTheme.brutalBox(
                              context,
                              color: AppColors.bg(context),
                              shadow: true,
                            ),
                            child: Icon(
                              Icons.close,
                              size: layout.inset(22),
                              color: AppColors.fg(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: layout.gap(14)),
                    _buildSearchField(context, vm),
                    if (showTabs) ...[
                      SizedBox(height: layout.gap(12)),
                      _PlaceSearchTabs(
                        selectedTab: _selectedTab,
                        allCount: vm.placeSearchResults.length,
                        savedCount: _savedResults(vm.placeSearchResults).length,
                        onChanged: (tab) {
                          setState(() {
                            _selectedTab = tab;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: _buildResults(context, vm, query)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, MapViewModel vm) {
    final layout = AppLayout.of(context);

    return Container(
      decoration: AppTheme.brutalBox(context, shadow: true),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        cursorColor: AppColors.fg(context),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _runSearch(force: true),
        style: GoogleFonts.spaceMono(
          color: AppColors.fg(context),
          fontSize: layout.font(13),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'SEARCH A PLACE OR ADDRESS...',
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
      ),
    );
  }

  Widget? _buildSearchFieldAction(BuildContext context, MapViewModel vm) {
    final layout = AppLayout.of(context);
    if (_hasQuery) {
      return IconButton(
        tooltip: 'Clear search',
        onPressed: () {
          _controller.clear();
          ref.read(mapViewModelProvider).clearPlaceSearch();
        },
        icon: Icon(
          Icons.close,
          color: AppColors.fg(context),
          size: layout.inset(20),
        ),
      );
    }

    if (!vm.isSearchingPlaces) {
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

  Widget _buildResults(BuildContext context, MapViewModel vm, String query) {
    final layout = AppLayout.of(context);
    final allResults = vm.placeSearchResults;
    final savedResults = _savedResults(allResults);
    final visibleResults = switch (_selectedTab) {
      _PlaceSearchTab.all => allResults,
      _PlaceSearchTab.saved => savedResults,
    };

    if (vm.isSearchingPlaces) {
      return _PlaceSearchMessage(
        icon: Icons.search,
        title: 'SEARCHING PLACES...',
        accentColor: AppColors.yellow,
        isLoading: true,
      );
    }

    if (vm.placeSearchError != null) {
      return _PlaceSearchMessage(
        icon: Icons.error_outline,
        title: 'SEARCH FAILED',
        body: vm.placeSearchError!.toUpperCase(),
        accentColor: AppColors.destructive,
      );
    }

    if (query.length >= 2 && allResults.isEmpty) {
      if (vm.isPlaceSuggestionUnavailable) {
        return _PlaceSearchMessage(
          icon: Icons.cloud_off,
          title: 'PLACE SUGGESTIONS UNAVAILABLE',
          body:
              'ONLY YOUR SAVED PLACES COULD BE SEARCHED. '
              'TRY AGAIN IN A MOMENT.',
          accentColor: AppColors.destructive,
        );
      }
      return _PlaceSearchMessage(
        icon: Icons.search_off,
        title: 'NO PLACES FOUND',
        body: 'TRY A DIFFERENT PLACE NAME OR ADDRESS.',
        accentColor: AppColors.yellow,
      );
    }

    if (query.length >= 2 &&
        _selectedTab == _PlaceSearchTab.saved &&
        visibleResults.isEmpty) {
      return _PlaceSearchMessage(
        icon: Icons.bookmark_border,
        title: 'NO SAVED PLACES FOUND',
        body: 'SAVED PLACES THAT MATCH THIS SEARCH WILL SHOW HERE.',
        accentColor: AppColors.yellow,
      );
    }

    if (query.length < 2 || visibleResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final resultsList = ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        layout.inset(20),
        layout.gap(16),
        layout.inset(20),
        layout.gap(28),
      ),
      itemCount: visibleResults.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _PlaceSearchSummary(
            count: visibleResults.length,
            query: query,
            tab: _selectedTab,
          );
        }

        final resultIndex = index - 1;
        final result = visibleResults[resultIndex];
        final resultKey = _placeResultKey(result, resultIndex);
        return _MapPlaceResultTile(
          result: result,
          isSaving: _savingResultKey == resultKey,
          onTap: () {
            unawaited(_handleResultTap(result, resultKey));
          },
        );
      },
    );

    if (!vm.isPlaceSuggestionUnavailable) return resultsList;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.inset(20),
            layout.gap(12),
            layout.inset(20),
            0,
          ),
          child: const _PlaceSearchNotice(),
        ),
        Expanded(child: resultsList),
      ],
    );
  }

  List<MapPlaceSearchResult> _savedResults(List<MapPlaceSearchResult> results) {
    return results
        .where((result) => result.isExisting || result.mapItem != null)
        .toList(growable: false);
  }

  String _placeResultKey(MapPlaceSearchResult result, int index) {
    return [
      index,
      result.googlePlaceId,
      result.displayTitle,
      result.displayAddress,
    ].whereType<Object>().join('|');
  }
}

enum _PlaceSearchTab { all, saved }

class _PlaceSearchTabs extends StatelessWidget {
  const _PlaceSearchTabs({
    required this.selectedTab,
    required this.allCount,
    required this.savedCount,
    required this.onChanged,
  });

  final _PlaceSearchTab selectedTab;
  final int allCount;
  final int savedCount;
  final ValueChanged<_PlaceSearchTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Container(
      decoration: AppTheme.brutalBox(context, shadow: false),
      child: Row(
        children: [
          Expanded(
            child: _PlaceSearchTabButton(
              label: 'ALL',
              count: allCount,
              isSelected: selectedTab == _PlaceSearchTab.all,
              onTap: () => onChanged(_PlaceSearchTab.all),
            ),
          ),
          Container(
            width: AppTheme.borderWidth,
            height: layout.inset(42),
            color: AppColors.fg(context),
          ),
          Expanded(
            child: _PlaceSearchTabButton(
              label: 'SAVED',
              count: savedCount,
              isSelected: selectedTab == _PlaceSearchTab.saved,
              onTap: () => onChanged(_PlaceSearchTab.saved),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchTabButton extends StatelessWidget {
  const _PlaceSearchTabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: layout.inset(42),
        color: isSelected ? AppColors.yellow : AppColors.bg(context),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: isSelected ? AppColors.black : AppColors.fg(context),
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: layout.inset(6)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.black : AppColors.yellow,
                  border: Border.all(
                    color: isSelected ? AppColors.black : AppColors.fg(context),
                    width: 2,
                  ),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.spaceMono(
                    color: isSelected ? AppColors.white : AppColors.black,
                    fontSize: layout.font(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchNotice extends StatelessWidget {
  const _PlaceSearchNotice();

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.inset(12)),
      decoration: AppTheme.brutalBox(
        context,
        color: AppColors.destructive,
        shadow: false,
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: AppColors.white,
            size: layout.inset(18),
          ),
          SizedBox(width: layout.inset(10)),
          Expanded(
            child: Text(
              'PLACE SUGGESTIONS UNAVAILABLE — SHOWING SAVED PLACES ONLY',
              style: GoogleFonts.spaceMono(
                color: AppColors.white,
                fontSize: layout.font(10),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchMessage extends StatelessWidget {
  const _PlaceSearchMessage({
    required this.icon,
    required this.title,
    required this.accentColor,
    this.body,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color accentColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final iconColor = accentColor.computeLuminance() > 0.5
        ? AppColors.black
        : AppColors.white;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.inset(28)),
        child: Container(
          width: double.infinity,
          decoration: AppTheme.brutalCard(context),
          padding: EdgeInsets.all(layout.inset(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: layout.inset(54),
                height: layout.inset(54),
                decoration: AppTheme.brutalBox(
                  context,
                  color: accentColor,
                  shadow: false,
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: layout.inset(24),
                        height: layout.inset(24),
                        child: CircularProgressIndicator(
                          color: iconColor,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: layout.inset(26)),
              ),
              SizedBox(height: layout.gap(16)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  color: AppColors.fg(context),
                  fontSize: layout.font(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (body != null && body!.isNotEmpty) ...[
                SizedBox(height: layout.gap(8)),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppColors.textSec(context),
                    fontSize: layout.font(11),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchSummary extends StatelessWidget {
  const _PlaceSearchSummary({
    required this.count,
    required this.query,
    required this.tab,
  });

  final int count;
  final String query;
  final _PlaceSearchTab tab;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final label = tab == _PlaceSearchTab.saved ? 'SAVED PLACE' : 'PLACE RESULT';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.yellow,
            border: Border.all(color: AppColors.fg(context), width: 2),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.spaceMono(
              color: AppColors.black,
              fontSize: layout.font(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: layout.inset(8)),
        Expanded(
          child: Text(
            '$label${count == 1 ? '' : 'S'} FOR "${query.toUpperCase()}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: AppColors.textSec(context),
              fontSize: layout.font(11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPlaceResultTile extends StatelessWidget {
  const _MapPlaceResultTile({
    required this.result,
    required this.isSaving,
    required this.onTap,
  });

  final MapPlaceSearchResult result;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final mapItem = result.mapItem;
    final isExisting = result.isExisting;
    final title = _firstNonEmpty([
      result.displayTitle,
      mapItem?.displayName,
      result.placeName,
    ]);
    final subtitle = _firstNonEmpty([
      result.displayAddress,
      mapItem?.locationDisplayLabel,
      mapItem?.displayDetail,
    ]);
    final badgeText = isExisting ? 'SAVED' : null;

    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: Container(
        padding: EdgeInsets.all(layout.inset(14)),
        decoration: AppTheme.brutalBox(
          context,
          color: AppColors.bg(context),
          shadow: true,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badgeText != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonGreen,
                          border: Border.all(
                            color: AppColors.fg(context),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.spaceMono(
                            color: AppColors.black,
                            fontSize: layout.font(10),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: layout.gap(8)),
                  ],
                  Text(
                    title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: layout.gap(4)),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceMono(
                        color: AppColors.textSec(context),
                        fontSize: layout.font(10),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isExisting) ...[
              SizedBox(width: layout.inset(10)),
              SizedBox(
                width: layout.inset(36),
                height: layout.inset(36),
                child: Center(
                  child: isSaving
                      ? SizedBox(
                          width: layout.inset(18),
                          height: layout.inset(18),
                          child: CircularProgressIndicator(
                            color: AppColors.fg(context),
                            strokeWidth: 2,
                          ),
                        )
                      : Image.asset(
                          'assets/images/pin.png',
                          width: layout.inset(24),
                          height: layout.inset(24),
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
