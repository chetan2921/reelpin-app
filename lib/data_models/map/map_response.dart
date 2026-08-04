import 'package:reelpin/features/reels/domain/reel.dart';

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
    this.mapItemId,
    this.sourceType = 'reel',
    this.sourceId,
    this.displayTitle = '',
    this.shortDetail = '',
    this.subCategoryLabel = '',
    this.locationAddress,
    this.googleMapsUrl,
    this.googlePlaceId,
    this.placeTypes = const [],
    this.canHide = true,
    this.canRemove = true,
  });

  final String reelId;
  final String title;
  final String summary;
  final String category;
  final String subCategory;
  final String categoryLabel;
  final String subCategoryLabel;
  final List<Location> locations;
  final String markerId;
  final double latitude;
  final double longitude;
  final String? mapItemId;
  final String sourceType;
  final String? sourceId;
  final String displayTitle;
  final String shortDetail;
  final String locationName;
  final String? locationAddress;
  final String locationDisplayLabel;
  final String? googleMapsUrl;
  final String? googlePlaceId;
  final List<String> placeTypes;
  final bool canHide;
  final bool canRemove;

  bool get isManual => sourceType == 'manual';
  bool get canOpenDetails => reelId.trim().isNotEmpty;
  String get effectiveMapItemId => mapItemId ?? markerId;
  String get displayName =>
      displayTitle.trim().isNotEmpty ? displayTitle : title;
  String get displayDetail =>
      shortDetail.trim().isNotEmpty ? shortDetail : summary;

  factory MapItem.fromJson(Map<String, dynamic> json) {
    double parseCoord(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    final rawLocations = json['locations'] as List<dynamic>? ?? const [];
    final rawPlaceTypes = json['place_types'] as List<dynamic>? ?? const [];
    final category = json['category']?.toString() ?? '';
    final subCategory =
        json['sub_category']?.toString() ??
        json['subcategory']?.toString() ??
        category;
    final locationName =
        json['location_name']?.toString() ??
        json['place_name']?.toString() ??
        '';
    final locationAddress =
        json['location_address']?.toString() ??
        json['display_address']?.toString();
    final displayTitle = json['display_title']?.toString() ?? '';
    final title = json['title']?.toString() ?? displayTitle;
    final shortDetail = json['short_detail']?.toString() ?? '';
    final summary = json['summary']?.toString() ?? shortDetail;
    final displayLabel =
        json['location_display_label']?.toString() ??
        json['display_address']?.toString() ??
        json['place_name']?.toString() ??
        locationName;
    final markerId =
        json['marker_id']?.toString() ??
        json['map_item_id']?.toString() ??
        json['reel_id']?.toString() ??
        json['id']?.toString() ??
        '';

    return MapItem(
      reelId: json['reel_id']?.toString() ?? json['id']?.toString() ?? '',
      title: title,
      summary: summary,
      category: category,
      subCategory: subCategory,
      categoryLabel: json['category_label']?.toString() ?? category,
      subCategoryLabel: json['sub_category_label']?.toString() ?? subCategory,
      locations: rawLocations
          .whereType<Map>()
          .map((row) => Location.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      markerId: markerId,
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      mapItemId: json['map_item_id']?.toString(),
      sourceType: json['source_type']?.toString() ?? 'reel',
      sourceId: json['source_id']?.toString(),
      displayTitle: displayTitle,
      shortDetail: shortDetail,
      locationName: locationName,
      locationAddress: locationAddress,
      locationDisplayLabel: displayLabel,
      googleMapsUrl: json['google_maps_url']?.toString(),
      googlePlaceId: json['google_place_id']?.toString(),
      placeTypes: rawPlaceTypes.map((type) => type.toString()).toList(),
      canHide: json['can_hide'] != false,
      canRemove: json['can_remove'] != false,
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
