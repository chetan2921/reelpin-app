import 'search_result.dart';
import 'user_entitlement.dart';

class SearchResponse {
  const SearchResponse({
    required this.query,
    required this.results,
    required this.total,
    required this.searchMode,
  });

  final String query;
  final List<SearchResult> results;
  final int total;
  final SearchMode searchMode;

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];
    return SearchResponse(
      query: json['query']?.toString() ?? '',
      results: rawResults
          .map(
            (row) =>
                SearchResult.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      searchMode: SearchMode.fromValue(json['search_mode']?.toString()),
    );
  }
}
