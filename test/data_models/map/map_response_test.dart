import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/map/map_response.dart';

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
}
