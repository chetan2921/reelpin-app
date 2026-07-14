import 'reel.dart';

class FolderSummary {
  const FolderSummary({
    required this.id,
    required this.name,
    this.note,
    this.reelCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? note;
  final int reelCount;
  final String? createdAt;
  final String? updatedAt;

  factory FolderSummary.fromJson(Map<String, dynamic> json) {
    return FolderSummary(
      id: (json['id'] ?? json['folder_id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      note: json['note']?.toString(),
      reelCount:
          (json['reel_count'] as num?)?.toInt() ??
          (json['reels_count'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  FolderSummary copyWith({
    String? id,
    String? name,
    String? note,
    int? reelCount,
    String? createdAt,
    String? updatedAt,
  }) {
    return FolderSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      reelCount: reelCount ?? this.reelCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FolderPagination {
  const FolderPagination({
    this.nextCursor,
    this.nextOffset,
    this.hasMore = false,
    this.limit = 25,
    this.offset = 0,
    this.totalCount = 0,
  });

  final String? nextCursor;
  final int? nextOffset;
  final bool hasMore;
  final int limit;
  final int offset;
  final int totalCount;

  factory FolderPagination.fromJson(Map<String, dynamic> json) {
    return FolderPagination(
      nextCursor: json['next_cursor']?.toString(),
      nextOffset: (json['next_offset'] as num?)?.toInt(),
      hasMore: json['has_more'] == true,
      limit: (json['limit'] as num?)?.toInt() ?? 25,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FolderDetailResponse {
  const FolderDetailResponse({
    required this.folder,
    required this.reels,
    required this.pagination,
  });

  final FolderSummary folder;
  final List<Reel> reels;
  final FolderPagination pagination;

  factory FolderDetailResponse.fromJson(Map<String, dynamic> json) {
    final folderPayload = json['folder'];
    final reelsPayload = json['reels'];
    final paginationPayload = json['pagination'];

    return FolderDetailResponse(
      folder: folderPayload is Map<String, dynamic>
          ? FolderSummary.fromJson(folderPayload)
          : FolderSummary.fromJson(json),
      reels: reelsPayload is List
          ? reelsPayload
                .whereType<Map>()
                .map((item) => Reel.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false)
          : const [],
      pagination: paginationPayload is Map<String, dynamic>
          ? FolderPagination.fromJson(paginationPayload)
          : FolderPagination.fromJson(json),
    );
  }

  FolderDetailResponse append(FolderDetailResponse next) {
    return FolderDetailResponse(
      folder: next.folder,
      reels: [...reels, ...next.reels],
      pagination: next.pagination,
    );
  }
}
