class ReelCategoryGroup {
  final String category;
  final List<String> subcategories;

  const ReelCategoryGroup({
    required this.category,
    required this.subcategories,
  });

  factory ReelCategoryGroup.fromJson(Map<String, dynamic> json) {
    final rawSubcategories = json['subcategories'];
    return ReelCategoryGroup(
      category: json['category']?.toString().trim() ?? '',
      subcategories: rawSubcategories is List
          ? rawSubcategories
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class ReelCategoryFiltersResponse {
  final String userId;
  final List<ReelCategoryGroup> categories;
  final int totalCategories;

  const ReelCategoryFiltersResponse({
    required this.userId,
    required this.categories,
    required this.totalCategories,
  });

  factory ReelCategoryFiltersResponse.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final categories = rawCategories is List
        ? rawCategories
              .map(
                (item) => ReelCategoryGroup.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .where((item) => item.category.isNotEmpty)
              .toList(growable: false)
        : const <ReelCategoryGroup>[];

    return ReelCategoryFiltersResponse(
      userId: json['user_id']?.toString().trim() ?? '',
      categories: categories,
      totalCategories:
          (json['total_categories'] as num?)?.toInt() ?? categories.length,
    );
  }
}

class ReelCategoryCatalog {
  ReelCategoryCatalog._();

  static List<ReelCategoryGroup> _groups = const [];

  static List<ReelCategoryGroup> get groups => List.unmodifiable(_groups);

  static List<String> get categories =>
      _groups.map((group) => group.category).toList(growable: false);

  static void replaceAll(List<ReelCategoryGroup> groups) {
    _groups = List<ReelCategoryGroup>.unmodifiable(groups);
  }

  static String? parentCategoryFor(String? value) {
    final label = value?.trim();
    if (label == null || label.isEmpty) return null;

    for (final group in _groups) {
      if (_matches(group.category, label)) {
        return group.category;
      }
      for (final subcategory in group.subcategories) {
        if (_matches(subcategory, label)) {
          return group.category;
        }
      }
    }

    return null;
  }

  static List<String> subcategoriesFor(String? category) {
    final label = category?.trim();
    if (label == null || label.isEmpty) return const [];

    for (final group in _groups) {
      if (_matches(group.category, label)) {
        return List<String>.unmodifiable(group.subcategories);
      }
    }

    return const [];
  }

  static bool _matches(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();
}
