import 'reel.dart';

class ReelPage {
  const ReelPage({
    required this.reels,
    required this.hasMore,
    required this.totalCount,
    required this.limit,
    required this.offset,
    this.nextCursor,
    this.nextOffset,
  });

  final List<Reel> reels;
  final String? nextCursor;
  final int? nextOffset;
  final bool hasMore;
  final int totalCount;
  final int limit;
  final int offset;

  factory ReelPage.fromJson(Map<String, dynamic> json) {
    final rawReels = json['reels'] as List<dynamic>? ?? const [];
    return ReelPage(
      reels: rawReels
          .map((row) => Reel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      nextCursor: json['next_cursor']?.toString(),
      nextOffset: (json['next_offset'] as num?)?.toInt(),
      hasMore: json['has_more'] == true,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}
