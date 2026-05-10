import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/reel_category_filters.dart';

void main() {
  test('parses dynamic category filters and maps subcategories to parents', () {
    final response = ReelCategoryFiltersResponse.fromJson({
      'user_id': 'user-123',
      'categories': [
        {
          'category': 'Movies',
          'subcategories': ['Trailers', 'Reviews'],
        },
        {
          'category': 'Travel',
          'subcategories': ['Food Guides'],
        },
      ],
      'total_categories': 2,
    });

    expect(response.userId, 'user-123');
    expect(response.totalCategories, 2);
    expect(response.categories.first.category, 'Movies');

    final catalog = ReelCategoryCatalog(response.categories);

    expect(catalog.categories, ['Movies', 'Travel']);
    expect(catalog.parentCategoryFor('Trailers'), 'Movies');
    expect(catalog.subcategoriesFor('Travel'), ['Food Guides']);
  });
}
