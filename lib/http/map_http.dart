import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';

abstract interface class MapHttp {
  Future<MapResponse> getMapData({String? category});

  Future<MapPlaceSearchResponse> searchMapPlaces(
    String query, {
    String? category,
    String? sessionToken,
    int limit = 8,
  });

  Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken});

  Future<void> removeMapItem(String mapItemId);
}
