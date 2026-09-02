import 'package:reelpin/data_models/map/map_response.dart';

class MapPlaceSearchResponse {
  const MapPlaceSearchResponse({
    required this.query,
    required this.searchMode,
    required this.total,
    required this.results,
    this.googleStatus = 'ok',
  });

  final String query;
  final String searchMode;
  final int total;
  final List<MapPlaceSearchResult> results;

  /// 'ok', 'failed' or 'not_configured' — the backend reports when Google
  /// Places could not be reached, so an empty list is not read as "no matches".
  final String googleStatus;

  bool get isGoogleSearchUnavailable => googleStatus != 'ok';

  factory MapPlaceSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];
    return MapPlaceSearchResponse(
      query: json['query']?.toString() ?? '',
      searchMode: json['search_mode']?.toString() ?? '',
      googleStatus: json['google_status']?.toString() ?? 'ok',
      total: (json['total'] as num?)?.toInt() ?? 0,
      results: rawResults
          .map(
            (row) => MapPlaceSearchResult.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class MapPlaceSearchResult {
  const MapPlaceSearchResult({
    required this.resultType,
    this.sourceType,
    this.mapItem,
    this.googlePlaceId,
    required this.displayTitle,
    required this.displayAddress,
    required this.placeName,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    required this.placeTypes,
    required this.canPin,
  });

  final String resultType;
  final String? sourceType;
  final MapItem? mapItem;
  final String? googlePlaceId;
  final String displayTitle;
  final String displayAddress;
  final String placeName;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final List<String> placeTypes;
  final bool canPin;

  bool get isExisting => resultType == 'existing' && mapItem != null;
  bool get isGooglePlace => googlePlaceId != null && googlePlaceId!.isNotEmpty;

  factory MapPlaceSearchResult.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final rawTypes = json['place_types'] as List<dynamic>? ?? const [];
    final rawMapItem = json['map_item'];

    return MapPlaceSearchResult(
      resultType: json['result_type']?.toString() ?? '',
      sourceType: json['source_type']?.toString(),
      mapItem: rawMapItem is Map
          ? MapItem.fromJson(Map<String, dynamic>.from(rawMapItem))
          : null,
      googlePlaceId: json['google_place_id']?.toString(),
      displayTitle: json['display_title']?.toString() ?? '',
      displayAddress: json['display_address']?.toString() ?? '',
      placeName: json['place_name']?.toString() ?? '',
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      googleMapsUrl: json['google_maps_url']?.toString(),
      placeTypes: rawTypes.map((type) => type.toString()).toList(),
      canPin: json['can_pin'] == true,
    );
  }
}
