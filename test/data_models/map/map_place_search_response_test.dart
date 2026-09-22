import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/map/map_place_search_response.dart';

void main() {
  test('parses the google status reported by the backend', () {
    final response = MapPlaceSearchResponse.fromJson(const {
      'query': 'brew',
      'search_mode': 'existing',
      'google_status': 'failed',
      'total': 0,
      'results': <Map<String, dynamic>>[],
    });

    expect(response.googleStatus, 'failed');
    expect(response.isGoogleSearchUnavailable, isTrue);
  });

  test('treats a response without a google status as healthy', () {
    final response = MapPlaceSearchResponse.fromJson(const {
      'query': 'brew',
      'search_mode': 'existing',
      'total': 0,
      'results': <Map<String, dynamic>>[],
    });

    expect(response.googleStatus, 'ok');
    expect(response.isGoogleSearchUnavailable, isFalse);
  });
}
