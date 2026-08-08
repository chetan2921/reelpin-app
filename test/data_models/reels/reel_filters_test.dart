import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';

Map<String, dynamic> _response() => {
  'total_count': 12,
  'top_platform': 'instagram',
  'selected_preview_count': 6,
  'platforms': [
    {
      'platform': 'instagram',
      'label': 'Instagram',
      'count': 8,
      'top_category': 'Movies',
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
          'count': 2,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 2},
          ],
        },
      ],
    },
    {
      'platform': 'youtube',
      'label': 'YouTube',
      'count': 4,
      'top_category': 'Travel',
      'categories': [
        {
          'category': 'Travel',
          'label': 'Travel',
          'count': 4,
          'subcategories': [
            {'name': 'Food Guides', 'label': 'Food Guides', 'count': 4},
          ],
        },
      ],
    },
  ],
  'categories': [
    {
      'category': 'Travel',
      'label': 'Travel',
      'count': 6,
      'subcategories': [
        {'name': 'Food Guides', 'label': 'Food Guides', 'count': 6},
      ],
    },
    {
      'category': 'Movies',
      'label': 'Movies',
      'count': 6,
      'subcategories': [
        {'name': 'Trailers', 'label': 'Trailers', 'count': 4},
        {'name': 'Reviews', 'label': 'Reviews', 'count': 2},
      ],
    },
  ],
};

void main() {
  test('parses the platform facet tree', () {
    final response = ReelFiltersResponse.fromJson(_response());

    expect(response.totalCount, 12);
    expect(response.topPlatform, 'instagram');
    expect(response.selectedPreviewCount, 6);

    expect(response.platforms.map((group) => group.platform), [
      'instagram',
      'youtube',
    ]);

    final instagram = response.platforms.first;
    expect(instagram.label, 'Instagram');
    expect(instagram.count, 8);
    expect(instagram.topCategory, 'Movies');
    expect(instagram.categories.first.category, 'Movies');
    expect(instagram.categories.first.subcategories.first.name, 'Trailers');
  });

  test('parses the cross-platform category aggregate', () {
    final response = ReelFiltersResponse.fromJson(_response());

    expect(response.categories.map((group) => group.category), [
      'Travel',
      'Movies',
    ]);
    // Every platform's Travel saves roll up into the aggregate.
    expect(response.categories.first.count, 6);
  });

  test('looks platforms, categories and subcategories up by name', () {
    final response = ReelFiltersResponse.fromJson(_response());

    final youtube = response.platformNamed('youtube');
    expect(youtube, isNotNull);
    expect(youtube!.count, 4);
    expect(youtube.categoryNamed('Travel')?.count, 4);
    expect(youtube.categoryNamed('Movies'), isNull);
    expect(
      youtube.categoryNamed('Travel')?.subcategoryNamed('Food Guides')?.count,
      4,
    );
    expect(response.platformNamed('pinterest'), isNull);
    expect(response.platformNamed(null), isNull);
  });

  test('upper-cases display labels so backend title-casing cannot leak', () {
    final response = ReelFiltersResponse.fromJson({
      'total_count': 1,
      'platforms': [
        {
          'platform': 'youtube',
          'label': 'YouTube',
          'count': 1,
          'categories': [
            // The backend derives labels by title-casing, which mangles
            // acronyms; upper-casing for display makes that invisible.
            {
              'category': 'TV & Series',
              'label': 'Tv & Series',
              'count': 1,
              'subcategories': [
                {'name': 'AI Development', 'label': 'Ai Development'},
              ],
            },
          ],
        },
      ],
    });

    final platform = response.platforms.single;
    expect(platform.displayLabel, 'YOUTUBE');

    final category = platform.categories.single;
    expect(category.displayLabel, 'TV & SERIES');
    // The wire value is preserved untouched — it is what gets filtered on.
    expect(category.category, 'TV & Series');
    expect(category.subcategories.single.displayLabel, 'AI DEVELOPMENT');
    expect(category.subcategories.single.name, 'AI Development');
  });

  test('tolerates a missing or malformed tree', () {
    final response = ReelFiltersResponse.fromJson({});

    expect(response.totalCount, 0);
    expect(response.topPlatform, isNull);
    expect(response.platforms, isEmpty);
    expect(response.categories, isEmpty);
  });

  test('drops entries with no usable identifier', () {
    final response = ReelFiltersResponse.fromJson({
      'platforms': [
        {'platform': '', 'label': 'Nameless', 'count': 3},
        {'platform': 'reddit', 'label': 'Reddit', 'count': 1},
      ],
      'categories': [
        {'category': '  ', 'count': 2},
      ],
    });

    expect(response.platforms.map((group) => group.platform), ['reddit']);
    expect(response.categories, isEmpty);
  });

  test('accepts subcategories sent as bare strings', () {
    final response = ReelFiltersResponse.fromJson({
      'platforms': [
        {
          'platform': 'x',
          'label': 'X',
          'count': 2,
          'categories': [
            {
              'category': 'Sports',
              'count': 2,
              'subcategories': ['Tennis', ''],
            },
          ],
        },
      ],
    });

    final subcategories =
        response.platforms.single.categories.single.subcategories;
    expect(subcategories.map((item) => item.name), ['Tennis']);
    expect(subcategories.single.count, 0);
  });
}
