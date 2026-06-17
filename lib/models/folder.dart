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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      note: _cleanOptionalText(json['note']),
      reelCount: (json['reel_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  FolderSummary copyWith({
    String? id,
    String? name,
    Object? note = _sentinel,
    int? reelCount,
    String? createdAt,
    String? updatedAt,
  }) {
    return FolderSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      note: identical(note, _sentinel) ? this.note : note as String?,
      reelCount: reelCount ?? this.reelCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    final rawReels = json['reels'] as List<dynamic>? ?? const [];
    return FolderDetailResponse(
      folder: FolderSummary.fromJson(
        Map<String, dynamic>.from(json['folder'] as Map? ?? const {}),
      ),
      reels: rawReels
          .map((row) => Reel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      pagination: FolderPagination.fromJson(
        Map<String, dynamic>.from(json['pagination'] as Map? ?? const {}),
      ),
    );
  }

  FolderDetailResponse copyWith({
    FolderSummary? folder,
    List<Reel>? reels,
    FolderPagination? pagination,
  }) {
    return FolderDetailResponse(
      folder: folder ?? this.folder,
      reels: reels ?? this.reels,
      pagination: pagination ?? this.pagination,
    );
  }
}

class FolderPagination {
  const FolderPagination({
    this.nextCursor,
    this.nextOffset,
    this.hasMore = false,
    this.totalCount = 0,
    this.limit = 0,
    this.offset = 0,
  });

  final String? nextCursor;
  final int? nextOffset;
  final bool hasMore;
  final int totalCount;
  final int limit;
  final int offset;

  factory FolderPagination.fromJson(Map<String, dynamic> json) {
    return FolderPagination(
      nextCursor: json['next_cursor']?.toString(),
      nextOffset: (json['next_offset'] as num?)?.toInt(),
      hasMore: json['has_more'] == true,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class FolderMutationResponse {
  const FolderMutationResponse({required this.folder, this.movedReelCount = 0});

  final FolderSummary folder;
  final int movedReelCount;

  factory FolderMutationResponse.fromJson(Map<String, dynamic> json) {
    return FolderMutationResponse(
      folder: FolderSummary.fromJson(
        Map<String, dynamic>.from(json['folder'] as Map? ?? const {}),
      ),
      movedReelCount: (json['moved_reel_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FolderConflict {
  const FolderConflict({
    required this.reelId,
    required this.currentFolderId,
    required this.currentFolderName,
  });

  final String reelId;
  final String currentFolderId;
  final String currentFolderName;

  factory FolderConflict.fromJson(Map<String, dynamic> json) {
    return FolderConflict(
      reelId: json['reel_id']?.toString() ?? '',
      currentFolderId: json['current_folder_id']?.toString() ?? '',
      currentFolderName: json['current_folder_name']?.toString() ?? '',
    );
  }
}

const _sentinel = Object();

String? _cleanOptionalText(dynamic value) {
  if (value == null) return null;
  final cleaned = value.toString().trim();
  return cleaned.isEmpty ? null : cleaned;
}
