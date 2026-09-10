import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reelpin/utils/category_marker_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the marker icon differs between categories', () async {
    final food = await createCategoryMarkerIcon('Food') as BytesMapBitmap;
    final travel = await createCategoryMarkerIcon('Travel') as BytesMapBitmap;

    // Different categories get different colours from
    // AppColors.getCategoryColor, so the rendered pins are not identical.
    expect(food.byteData, isNot(equals(travel.byteData)));
  });

  test('the same category always renders the same icon', () async {
    final first = await createCategoryMarkerIcon('Food') as BytesMapBitmap;
    final second = await createCategoryMarkerIcon('Food') as BytesMapBitmap;

    expect(first.byteData, equals(second.byteData));
  });

  test(
    'createCategoryMarkerPng returns the same bytes the icon wraps',
    () async {
      final bytes = await createCategoryMarkerPng('Food');
      final icon = await createCategoryMarkerIcon('Food') as BytesMapBitmap;

      expect(bytes, equals(icon.byteData));
    },
  );

  test('createCategoryMarkerPng is valid PNG data', () async {
    final bytes = await createCategoryMarkerPng('Food');

    // PNG file signature.
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
