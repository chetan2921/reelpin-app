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
}

class ReelCategoryFiltersResponse {
  final int totalCount;
  final String? topCategory;
  final List<ReelCategoryGroup> categories;
  final int selectedPreviewCount;

  const ReelCategoryFiltersResponse({
    required this.totalCount,
    required this.topCategory,
    required this.categories,
    required this.selectedPreviewCount,
  });

  factory ReelCategoryFiltersResponse.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    return ReelCategoryFiltersResponse(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      topCategory: json['top_category']?.toString(),
      categories: rawCategories is List
          ? rawCategories
                .map(
                  (item) => ReelCategoryGroup.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .where((item) => item.category.isNotEmpty)
                .toList(growable: false)
          : const [],
      selectedPreviewCount:
          (json['selected_preview_count'] as num?)?.toInt() ?? 0,
    );
  }
}
