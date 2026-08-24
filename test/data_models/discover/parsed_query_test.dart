import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/discover/parsed_query.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';

const _facets = <ReelCategoryGroup>[
  ReelCategoryGroup(
    category: 'food',
    label: 'Food',
    count: 3,
    subcategories: [ReelSubcategoryFilter(name: 'cafe', label: 'Cafe', count: 2)],
  ),
];

void main() {
  test('parses a well-formed payload', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'coffee shops', 'category': 'food', 'limit': 5},
      rawQuery: 'top 5 cofee shops',
      facets: _facets,
    );

    expect(parsed!.semanticQuery, 'coffee shops');
    expect(parsed.category, 'food');
    expect(parsed.limit, 5);
    expect(parsed.rawQuery, 'top 5 cofee shops');
  });

  test('drops a category that is not in the facet tree', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'cafes', 'category': 'cafes'},
      rawQuery: 'cafes',
      facets: _facets,
    );

    expect(parsed!.category, isNull);
    expect(parsed.semanticQuery, 'cafes');
  });

  test('drops a subcategory that is not in the facet tree', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'cafes', 'category': 'food', 'subcategory': 'bistro'},
      rawQuery: 'cafes',
      facets: _facets,
    );

    expect(parsed!.category, 'food');
    expect(parsed.subcategory, isNull);
  });

  test('keeps a subcategory that is in the facet tree', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'flat white', 'category': 'food', 'subcategory': 'cafe'},
      rawQuery: 'flat white',
      facets: _facets,
    );

    expect(parsed!.subcategory, 'cafe');
  });

  test('drops a subcategory when its parent category was rejected', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'cafes', 'category': 'nonsense', 'subcategory': 'cafe'},
      rawQuery: 'cafes',
      facets: _facets,
    );

    expect(parsed!.category, isNull);
    expect(parsed.subcategory, isNull);
  });

  test('clamps out-of-range limits', () {
    final high = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'x', 'limit': 900},
      rawQuery: 'x',
      facets: _facets,
    );
    final low = ParsedQuery.fromGeminiJson(
      {'semantic_query': 'x', 'limit': 0},
      rawQuery: 'x',
      facets: _facets,
    );

    expect(high!.limit, 50);
    expect(low!.limit, 1);
  });

  test('returns null when semantic_query is empty', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'semantic_query': '   '},
      rawQuery: 'x',
      facets: _facets,
    );

    expect(parsed, isNull);
  });

  test('returns null when semantic_query is missing entirely', () {
    final parsed = ParsedQuery.fromGeminiJson(
      {'category': 'food'},
      rawQuery: 'x',
      facets: _facets,
    );

    expect(parsed, isNull);
  });

  test('fallback keeps the raw query and drops every facet', () {
    final parsed = ParsedQuery.fallback('travel in Karnataka');

    expect(parsed.semanticQuery, 'travel in Karnataka');
    expect(parsed.category, isNull);
    expect(parsed.subcategory, isNull);
    expect(parsed.limit, isNull);
    expect(parsed.rawQuery, 'travel in Karnataka');
  });
}
