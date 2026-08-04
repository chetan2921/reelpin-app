import 'package:http/http.dart' as http;
import 'package:reelpin/data_models/discover/discover_response.dart';
import 'package:reelpin/data_models/discover/search_response.dart';

abstract interface class DiscoverHttp {
  Future<SearchResponse> searchReels(
    String query, {
    String userId = 'default-user',
    String? category,
    String? subcategory,
    int limit = 5,
    http.Client? client,
  });

  Future<DiscoverResponse> getDiscover({
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 25,
  });
}
