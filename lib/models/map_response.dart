import 'reel.dart';

class MapResponse {
  const MapResponse({
    required this.totalPinnedLocations,
    required this.visiblePinnedLocations,
    required this.mapItems,
    this.selectedCategory,
  });

  final int totalPinnedLocations;
  final int visiblePinnedLocations;
  final String? selectedCategory;
  final List<MapItem> mapItems;

  factory MapResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['map_items'] as List<dynamic>? ?? const [];
    return MapResponse(
      totalPinnedLocations:
          (json['total_pinned_locations'] as num?)?.toInt() ?? 0,
      visiblePinnedLocations:
          (json['visible_pinned_locations'] as num?)?.toInt() ?? 0,
      selectedCategory: json['selected_category']?.toString(),
      mapItems: rawItems
          .map((row) => MapItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
    );
  }
}

class MapItem {
  const MapItem({
    required this.reelId,
    required this.title,
    required this.summary,
    required this.category,
    required this.subCategory,
    required this.categoryLabel,
    required this.locations,
    required this.markerId,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.locationDisplayLabel,
    this.locationAddress,
    this.googleMapsUrl,
  });

  final String reelId;
  final String title;
  final String summary;
  final String category;
  final String subCategory;
  final String categoryLabel;
  final List<Location> locations;
  final String markerId;
  final double latitude;
  final double longitude;
  final String locationName;
  final String? locationAddress;
  final String locationDisplayLabel;
  final String? googleMapsUrl;

  factory MapItem.fromJson(Map<String, dynamic> json) {
    double parseCoord(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    final rawLocations = json['locations'] as List<dynamic>? ?? const [];
    final category = json['category']?.toString() ?? '';
    final subCategory =
        json['sub_category']?.toString() ??
        json['subcategory']?.toString() ??
        category;

    return MapItem(
      reelId: json['reel_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      category: category,
      subCategory: subCategory,
      categoryLabel: json['category_label']?.toString() ?? category,
      locations: rawLocations
          .whereType<Map>()
          .map((row) => Location.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      markerId:
          json['marker_id']?.toString() ??
          json['reel_id']?.toString() ??
          json['id']?.toString() ??
          '',
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      locationName: json['location_name']?.toString() ?? '',
      locationAddress: json['location_address']?.toString(),
      locationDisplayLabel:
          json['location_display_label']?.toString() ??
          json['location_name']?.toString() ??
          '',
      googleMapsUrl: json['google_maps_url']?.toString(),
    );
  }

  Reel toReel() {
    return Reel(
      id: reelId,
      userId: '',
      url: '',
      sourceUrl: '',
      originalUrl: '',
      normalizedUrl: '',
      title: title,
      summary: summary,
      caption: '',
      transcript: '',
      category: category,
      subCategory: subCategory,
      categoryLabel: categoryLabel,
      subCategoryLabel: subCategory,
      keyFacts: const [],
      locations: locations,
      mappableLocations: locations,
      peopleMentioned: const [],
      actionableItems: const [],
      hasMapLocations: true,
      primaryLocationLabel: locationDisplayLabel,
      mapLocationCount: locations.length,
    );
  }
}
