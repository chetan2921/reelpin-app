import 'package:reelpin/data_models/reels/reel.dart';

class ReelPage {
  const ReelPage({required this.reels, required this.limit, this.nextCursor});

  final List<Reel> reels;
  final String? nextCursor;
  final int limit;

  bool get hasMore => nextCursor != null;

  factory ReelPage.fromJson(Map<String, dynamic> json) {
    final rawReels = json['reels'] as List<dynamic>? ?? const [];
    return ReelPage(
      reels: rawReels
          .map((row) => Reel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      nextCursor: json['next_cursor']?.toString(),
      limit: (json['limit'] as num?)?.toInt() ?? 0,
    );
  }
}
