import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/map/map_response.dart';

import '../../fixtures/api_v2.dart';

Map<String, dynamic> _pin(Map<String, dynamic> extra) => {
  'id': 'loc-1',
  'reel_id': 'reel-1',
  'name': 'Brew Lab',
  'category': 'Food',
  'latitude': 12.9,
  'longitude': 77.6,
  ...extra,
};

void main() {
  test('reads a map pin sub_category', () {
    final item = MapItem.fromJson(_pin({'sub_category': 'Cafes'}));

    expect(item.subCategory, 'Cafes');
  });

  test('falls back to the deprecated subcategory on a map pin', () {
    final item = MapItem.fromJson(_pin({'subcategory': 'Bakeries'}));

    expect(item.subCategory, 'Bakeries');
  });

  test('prefers sub_category when a pin carries both names', () {
    final item = MapItem.fromJson(
      _pin({'sub_category': 'Cafes', 'subcategory': 'Cafes'}),
    );

    expect(item.subCategory, 'Cafes');
  });

  test('keeps every pin the server returned for a category', () {
    final fixture = ApiV2Fixture('map_pins');

    final response = MapResponse.fromJson(fixture.body);

    expect(response.mapItems, hasLength(1));
    final pin = response.mapItems.single;
    expect(pin.category, 'food_and_drink');
    expect(pin.subCategory, 'cafes');
    expect(pin.reelId, '22222222-2222-4222-8222-222222222222');
  });

  test('reads a capped answer as truncated', () {
    final body = Map<String, dynamic>.from(ApiV2Fixture('map_pins').body)
      ..['truncated'] = true;

    final response = MapResponse.fromJson(body);

    expect(response.truncated, isTrue);
    expect(response.mapItems, hasLength(1));
  });

  test('an answer without truncated is not capped', () {
    final response = MapResponse.fromJson(ApiV2Fixture('map_pins').body);

    expect(response.truncated, isFalse);
  });

  test('a content pin is hidden through its bare location id', () {
    final pin = MapResponse.fromJson(
      ApiV2Fixture('map_pins').body,
    ).mapItems.single;

    expect(pin.isManual, isFalse);
    expect(pin.effectiveMapItemId, '66666666-6666-4666-8666-666666666666');
    expect(pin.canHide, isTrue);
    expect(pin.canRemove, isFalse);
  });

  test('a manual pin is removed through its manual: id', () {
    final pin = MapItem.fromJson(
      _pin({'id': 'pin-1', 'kind': 'manual', 'reel_id': null}),
    );

    expect(pin.isManual, isTrue);
    expect(pin.effectiveMapItemId, 'manual:pin-1');
    expect(pin.canHide, isFalse);
    expect(pin.canRemove, isTrue);
  });
}
