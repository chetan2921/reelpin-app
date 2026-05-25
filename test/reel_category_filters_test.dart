import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel_category_filters.dart';

void main() {
  test('parses backend category filter response', () {
    final response = ReelCategoryFiltersResponse.fromJson({
      'total_count': 12,
      'top_category': 'Movies',
      'selected_preview_count': 6,
      'categories': [
        {
          'category': 'Movies',
          'label': 'Movies',
          'count': 6,
          'subcategories': [
            {'name': 'Trailers', 'label': 'Trailers', 'count': 4},
            {'name': 'Reviews', 'label': 'Reviews', 'count': 2},
          ],
        },
        {
          'category': 'Travel',
          'label': 'Travel',
          'count': 6,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 6},
          ],
        },
      ],
    });

    expect(response.totalCount, 12);
    expect(response.topCategory, 'Movies');
    expect(response.selectedPreviewCount, 6);
    expect(response.categories.first.category, 'Movies');
    expect(response.categories.first.count, 6);

    expect(response.categories.map((group) => group.category), [
      'Movies',
      'Travel',
    ]);
    expect(response.categories.last.subcategories.first.name, 'Food Guides');
  });
}
