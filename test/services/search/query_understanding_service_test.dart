import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/services/search/query_understanding_service.dart';

const _facets = <ReelCategoryGroup>[
  ReelCategoryGroup(
    category: 'food',
    label: 'Food',
    count: 3,
    subcategories: [ReelSubcategoryFilter(name: 'cafe', label: 'Cafe', count: 2)],
  ),
  ReelCategoryGroup(
    category: 'travel',
    label: 'Travel',
    count: 5,
    subcategories: [],
  ),
];

void main() {
  test('prompt lists every real category so the model cannot invent one', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('cafes in bangalore', _facets);

    expect(prompt, contains('food'));
    expect(prompt, contains('travel'));
    expect(prompt, contains('cafe'));
  });

  test('prompt carries the raw query verbatim', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('top 5 cofee shops in banglore', _facets);

    expect(prompt, contains('top 5 cofee shops in banglore'));
  });

  test('prompt asks for spelling correction', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('cofee', _facets).toLowerCase();

    expect(prompt, contains('spelling'));
  });

  test('prompt tells the model to keep place names in the query text', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('cafes in bangalore', _facets)
        .toLowerCase();

    expect(prompt, contains('place name'));
  });

  test('prompt survives an empty facet tree without naming categories', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('cafes', const []);

    expect(prompt, contains('cafes'));
    expect(prompt, contains('none known'));
  });

  test('a category with no subcategories is listed without a subcategory note', () {
    final service = GeminiQueryUnderstandingService();

    final prompt = service.buildPrompt('trips', _facets);

    expect(prompt, contains('- travel\n'));
    expect(prompt, contains('- food (subcategories: cafe)'));
  });
}
