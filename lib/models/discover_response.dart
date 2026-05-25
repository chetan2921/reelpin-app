import 'reel.dart';

class DiscoverResponse {
  const DiscoverResponse({
    required this.recentSaves,
    required this.recentSavesCount,
    required this.savedDates,
    required this.reelsForSelectedDate,
    required this.categoryGrid,
    required this.quickSearchPrompts,
    required this.pagination,
    this.selectedDate,
  });

  final List<Reel> recentSaves;
  final int recentSavesCount;
  final List<SavedDateOption> savedDates;
  final String? selectedDate;
  final List<Reel> reelsForSelectedDate;
  final List<DiscoverCategory> categoryGrid;
  final List<String> quickSearchPrompts;
  final DiscoverPagination pagination;

  factory DiscoverResponse.fromJson(Map<String, dynamic> json) {
    return DiscoverResponse(
      recentSaves: _reels(json['recent_saves']),
      recentSavesCount: (json['recent_saves_count'] as num?)?.toInt() ?? 0,
      savedDates: (json['saved_dates'] as List<dynamic>? ?? const [])
          .map((row) {
            if (row is Map) {
              return SavedDateOption.fromJson(Map<String, dynamic>.from(row));
            }
            final value = row.toString();
            return SavedDateOption(value: value, label: value);
          })
          .toList(growable: false),
      selectedDate: json['selected_date']?.toString(),
      reelsForSelectedDate: _reels(json['reels_for_selected_date']),
      categoryGrid: (json['category_grid'] as List<dynamic>? ?? const [])
          .map(
            (row) => DiscoverCategory.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      quickSearchPrompts:
          (json['quick_search_prompts'] as List<dynamic>? ?? const [])
              .map((row) => row.toString())
              .where((row) => row.trim().isNotEmpty)
              .toList(growable: false),
      pagination: DiscoverPagination.fromJson(
        Map<String, dynamic>.from(json['pagination'] as Map? ?? const {}),
      ),
    );
  }

  static List<Reel> _reels(dynamic raw) {
    return (raw as List<dynamic>? ?? const [])
        .map((row) => Reel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }
}

class SavedDateOption {
  const SavedDateOption({required this.value, required this.label});

  final String value;
  final String label;

  factory SavedDateOption.fromJson(Map<String, dynamic> json) {
    return SavedDateOption(
      value:
          json['saved_date_key']?.toString() ??
          json['date']?.toString() ??
          json['value']?.toString() ??
          '',
      label:
          json['display_label']?.toString() ??
          json['label']?.toString() ??
          json['date']?.toString() ??
          '',
    );
  }
}

class DiscoverCategory {
  const DiscoverCategory({
    required this.category,
    required this.label,
    required this.count,
  });

  final String category;
  final String label;
  final int count;

  factory DiscoverCategory.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString() ?? '';
    return DiscoverCategory(
      category: category,
      label: json['label']?.toString() ?? category,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DiscoverPagination {
  const DiscoverPagination({
    this.nextCursor,
    this.nextOffset,
    this.hasMore = false,
    this.limit = 0,
    this.offset = 0,
  });

  final String? nextCursor;
  final int? nextOffset;
  final bool hasMore;
  final int limit;
  final int offset;

  factory DiscoverPagination.fromJson(Map<String, dynamic> json) {
    return DiscoverPagination(
      nextCursor: json['next_cursor']?.toString(),
      nextOffset: (json['next_offset'] as num?)?.toInt(),
      hasMore: json['has_more'] == true,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
