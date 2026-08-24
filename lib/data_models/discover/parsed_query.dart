import 'package:reelpin/data_models/reels/reel_filters.dart';

/// A search sentence after Gemini has turned it into the parameters
/// `/api/v1/search` already accepts.
///
/// The backend ANDs every token in the query string, so moving a concept out of
/// [semanticQuery] and into [category] or [subcategory] widens the result set
/// rather than narrowing it — those arrive as separate filter parameters.
class ParsedQuery {
  const ParsedQuery({
    required this.semanticQuery,
    required this.rawQuery,
    this.category,
    this.subcategory,
    this.limit,
  });

  /// The search terms, spelling corrected, with anything promoted to a facet
  /// removed.
  final String semanticQuery;

  /// What the user actually typed. Kept for the fallback path and for logging.
  final String rawQuery;

  final String? category;
  final String? subcategory;
  final int? limit;

  /// What the app sends when parsing is unavailable: today's behaviour exactly.
  factory ParsedQuery.fallback(String rawQuery) =>
      ParsedQuery(semanticQuery: rawQuery, rawQuery: rawQuery);

  /// Validates a Gemini payload against the user's own facet tree.
  ///
  /// A facet the backend does not recognise would filter out correct results,
  /// so unrecognised values are dropped rather than forwarded — a null facet
  /// only widens the search. Returns null when the payload carries no usable
  /// query text, which the caller treats as a parse failure.
  static ParsedQuery? fromGeminiJson(
    Map<String, dynamic> json, {
    required String rawQuery,
    required List<ReelCategoryGroup> facets,
  }) {
    final semanticQuery = json['semantic_query']?.toString().trim() ?? '';
    if (semanticQuery.isEmpty) return null;

    // A subcategory is only meaningful under a category the tree knows, so a
    // rejected category takes its subcategory with it.
    final group = _groupNamed(facets, json['category']?.toString().trim());
    final subcategory = group
        ?.subcategoryNamed(json['subcategory']?.toString().trim())
        ?.name;

    final rawLimit = json['limit'];
    final limit = rawLimit is num ? rawLimit.toInt().clamp(1, 50) : null;

    return ParsedQuery(
      semanticQuery: semanticQuery,
      rawQuery: rawQuery,
      category: group?.category,
      subcategory: subcategory,
      limit: limit,
    );
  }

  static ReelCategoryGroup? _groupNamed(
    List<ReelCategoryGroup> facets,
    String? name,
  ) {
    if (name == null || name.isEmpty) return null;
    for (final group in facets) {
      if (group.category == name) return group;
    }
    return null;
  }
}
