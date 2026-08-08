/// The facet tree behind the home screen filter: platform → category →
/// subcategory.
///
/// A reel has exactly one source platform, so the counts nest exactly and the
/// backend can return the whole tree in one response. Everything below the
/// platform level is therefore resolved in-memory — picking a platform never
/// costs a round trip.
///
/// `category` / `name` / `platform` are the values sent back to the API;
/// `label` is display-only. The backend title-cases labels, so display copy
/// upper-cases them (which the app does everywhere anyway) rather than trusting
/// the casing it receives.
library;

class ReelSubcategoryFilter {
  final String name;
  final String label;
  final int count;

  const ReelSubcategoryFilter({
    required this.name,
    required this.label,
    required this.count,
  });

  factory ReelSubcategoryFilter.fromJson(Map<String, dynamic> json) {
    final name =
        json['name']?.toString().trim() ??
        json['subcategory']?.toString().trim() ??
        '';
    return ReelSubcategoryFilter(
      name: name,
      label: json['label']?.toString().trim() ?? name,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayLabel => label.toUpperCase();
}

class ReelCategoryGroup {
  final String category;
  final String label;
  final int count;
  final List<ReelSubcategoryFilter> subcategories;

  const ReelCategoryGroup({
    required this.category,
    required this.label,
    required this.count,
    required this.subcategories,
  });

  factory ReelCategoryGroup.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString().trim() ?? '';
    final rawSubcategories = json['subcategories'];
    return ReelCategoryGroup(
      category: category,
      label: json['label']?.toString().trim() ?? category,
      count: (json['count'] as num?)?.toInt() ?? 0,
      subcategories: rawSubcategories is List
          ? rawSubcategories
                .map((item) {
                  if (item is Map) {
                    return ReelSubcategoryFilter.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  final name = item.toString().trim();
                  return ReelSubcategoryFilter(
                    name: name,
                    label: name,
                    count: 0,
                  );
                })
                .where((item) => item.name.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  String get displayLabel => label.toUpperCase();

  ReelSubcategoryFilter? subcategoryNamed(String? name) {
    if (name == null) return null;
    for (final subcategory in subcategories) {
      if (subcategory.name == name) return subcategory;
    }
    return null;
  }
}

/// One social platform the user has actually saved from, with its own category
/// breakdown. The backend omits platforms with no saves, so this list is safe
/// to render verbatim — it never contains an empty tab.
class ReelPlatformGroup {
  final String platform;
  final String label;
  final int count;
  final String? topCategory;
  final List<ReelCategoryGroup> categories;

  const ReelPlatformGroup({
    required this.platform,
    required this.label,
    required this.count,
    required this.topCategory,
    required this.categories,
  });

  factory ReelPlatformGroup.fromJson(Map<String, dynamic> json) {
    final platform = json['platform']?.toString().trim() ?? '';
    return ReelPlatformGroup(
      platform: platform,
      label: json['label']?.toString().trim() ?? platform,
      count: (json['count'] as num?)?.toInt() ?? 0,
      topCategory: json['top_category']?.toString(),
      categories: _parseCategories(json['categories']),
    );
  }

  String get displayLabel => label.toUpperCase();

  ReelCategoryGroup? categoryNamed(String? category) {
    if (category == null) return null;
    for (final group in categories) {
      if (group.category == category) return group;
    }
    return null;
  }
}

class ReelFiltersResponse {
  final int totalCount;
  final String? topPlatform;
  final int selectedPreviewCount;
  final List<ReelPlatformGroup> platforms;

  /// The same category shape aggregated across every platform, so the "all
  /// platforms" state does not have to sum the per-platform trees.
  final List<ReelCategoryGroup> categories;

  const ReelFiltersResponse({
    required this.totalCount,
    required this.topPlatform,
    required this.selectedPreviewCount,
    required this.platforms,
    required this.categories,
  });

  factory ReelFiltersResponse.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'];
    return ReelFiltersResponse(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      topPlatform: json['top_platform']?.toString(),
      selectedPreviewCount:
          (json['selected_preview_count'] as num?)?.toInt() ?? 0,
      platforms: rawPlatforms is List
          ? rawPlatforms
                .map(
                  (item) => ReelPlatformGroup.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .where((item) => item.platform.isNotEmpty)
                .toList(growable: false)
          : const [],
      categories: _parseCategories(json['categories']),
    );
  }

  ReelPlatformGroup? platformNamed(String? platform) {
    if (platform == null) return null;
    for (final group in platforms) {
      if (group.platform == platform) return group;
    }
    return null;
  }
}

List<ReelCategoryGroup> _parseCategories(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map(
        (item) =>
            ReelCategoryGroup.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .where((item) => item.category.isNotEmpty)
      .toList(growable: false);
}
