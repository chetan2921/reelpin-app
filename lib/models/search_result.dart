import 'reel.dart';

class SearchResult {
  final Reel reel;
  final double relevanceScore;
  final String relevancePercent;
  final String displayScoreLabel;

  const SearchResult({
    required this.reel,
    required this.relevanceScore,
    this.relevancePercent = '',
    this.displayScoreLabel = '',
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      reel: Reel.fromJson(Map<String, dynamic>.from(json['reel'] as Map)),
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0,
      relevancePercent: json['relevance_percent']?.toString() ?? '',
      displayScoreLabel: json['display_score_label']?.toString() ?? '',
    );
  }
}
