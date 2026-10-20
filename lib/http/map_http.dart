import 'package:reelpin/data_models/map/map_bounds.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';

abstract interface class MapHttp {
  Future<MapResponse> getMapData({required MapBounds bounds, String? category});

  Future<MapResponse> getNearbyPins({
    required double latitude,
    required double longitude,
    int limit = 5,
  });

  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
    int limit = 8,
  });

  Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken});

  Future<void> removeMapItem(String mapItemId);
}
