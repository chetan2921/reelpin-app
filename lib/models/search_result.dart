import 'reel.dart';

class SearchResult {
  final Reel reel;
  final double relevanceScore;

  const SearchResult({required this.reel, required this.relevanceScore});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    reel: Reel.fromJson(json['reel'] as Map<String, dynamic>),
    relevanceScore: (json['relevance_score'] as num).toDouble(),
  );

  /// Relevance as a percentage string (e.g. "87%").
  String get relevancePercent => '${(relevanceScore * 100).round()}%';
}
