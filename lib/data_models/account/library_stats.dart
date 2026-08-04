class LibraryStats {
  const LibraryStats({
    required this.totalReels,
    required this.totalPinnedLocations,
    required this.totalTags,
    required this.totalCategories,
    required this.totalSubcategories,
  });

  final int totalReels;
  final int totalPinnedLocations;
  final int totalTags;
  final int totalCategories;
  final int totalSubcategories;

  factory LibraryStats.fromJson(Map<String, dynamic> json) {
    return LibraryStats(
      totalReels: (json['total_reels'] as num?)?.toInt() ?? 0,
      totalPinnedLocations:
          (json['total_pinned_locations'] as num?)?.toInt() ?? 0,
      totalTags: (json['total_tags'] as num?)?.toInt() ?? 0,
      totalCategories: (json['total_categories'] as num?)?.toInt() ?? 0,
      totalSubcategories: (json['total_subcategories'] as num?)?.toInt() ?? 0,
    );
  }
}
