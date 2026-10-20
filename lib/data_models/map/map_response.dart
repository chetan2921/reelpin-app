import 'package:reelpin/data_models/reels/reel.dart';

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

  /// Reads a `{pins: [...]}` answer. The pins endpoint has no category filter,
  /// so [category] narrows the pins here, the way the server used to.
  factory MapResponse.fromJson(Map<String, dynamic> json, {String? category}) {
    final pins = (json['pins'] as List<dynamic>? ?? const [])
        .map((row) => MapItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
    final hasCategory = category != null && category.trim().isNotEmpty;
    final visible = hasCategory
        ? pins.where((pin) => pin.category == category).toList(growable: false)
        : pins;
    return MapResponse(
      totalPinnedLocations: pins.length,
      visiblePinnedLocations: visible.length,
      selectedCategory: hasCategory ? category : null,
      mapItems: visible,
    );
  }
}

/// One pin on the map: a place from a saved reel (`kind` content) or one the
/// user pinned themselves (`kind` manual).
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
    this.sourceType = 'content',
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

    final id = json['id']?.toString() ?? '';
    final kind = json['kind']?.toString() ?? 'content';
    final name = json['name']?.toString() ?? '';
    final address = json['address']?.toString();
    final category = json['category']?.toString() ?? '';
    final subCategory =
        json['sub_category']?.toString() ??
        json['subcategory']?.toString() ??
        '';
    final latitude = parseCoord(json['latitude']);
    final longitude = parseCoord(json['longitude']);
    final rawPlaceTypes = json['place_types'] as List<dynamic>? ?? const [];

    return MapItem(
      reelId: json['reel_id']?.toString() ?? '',
      title: name,
      summary: '',
      category: category,
      subCategory: subCategory,
      categoryLabel: category,
      subCategoryLabel: subCategory,
      locations: [
        Location(
          name: name,
          address: address,
          latitude: latitude,
          longitude: longitude,
        ),
      ],
      markerId: id,
      latitude: latitude,
      longitude: longitude,
      // A bare id is always read as a location id, so a manual pin is removed
      // through its prefixed form.
      mapItemId: kind == 'manual' ? 'manual:$id' : id,
      sourceType: kind,
      displayTitle: name,
      shortDetail: address ?? '',
      locationName: name,
      locationAddress: address,
      locationDisplayLabel: name,
      googleMapsUrl: json['google_maps_url']?.toString(),
      googlePlaceId: json['google_place_id']?.toString(),
      placeTypes: rawPlaceTypes.map((type) => type.toString()).toList(),
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
