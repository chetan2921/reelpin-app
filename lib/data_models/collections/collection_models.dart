import 'package:reelpin/data_models/reels/reel.dart';

class CollectionSummary {
  const CollectionSummary({
    required this.id,
    required this.name,
    this.description = '',
    this.coverReelId,
    this.visibility = 'private',
    this.role = 'owner',
    this.itemCount = 0,
    this.memberCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String? coverReelId;
  final String visibility; // 'private' | 'link'
  final String role; // 'owner' | 'editor' | 'viewer'
  final int itemCount;
  final int memberCount;
  final String? createdAt;
  final String? updatedAt;

  bool get hasLink => visibility == 'link';
  bool get canEdit => role == 'owner' || role == 'editor';
  bool get isOwner => role == 'owner';

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    return CollectionSummary(
      id: (json['id'] ?? json['collection_id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverReelId: json['cover_reel_id']?.toString(),
      visibility: json['visibility']?.toString() ?? 'private',
      role: json['role']?.toString() ?? 'owner',
      itemCount:
          (json['item_count'] as num?)?.toInt() ??
          (json['items_count'] as num?)?.toInt() ??
          0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  /// Mirrors [fromJson] so a cached grid restores exactly as it arrived.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'cover_reel_id': coverReelId,
    'visibility': visibility,
    'role': role,
    'item_count': itemCount,
    'member_count': memberCount,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  CollectionSummary copyWith({
    String? name,
    String? description,
    String? coverReelId,
    String? visibility,
    String? role,
    int? itemCount,
    int? memberCount,
  }) {
    return CollectionSummary(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverReelId: coverReelId ?? this.coverReelId,
      visibility: visibility ?? this.visibility,
      role: role ?? this.role,
      itemCount: itemCount ?? this.itemCount,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CollectionPagination {
  const CollectionPagination({
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

  /// Mirrors [fromJson] so a cached detail restores exactly as it arrived.
  Map<String, dynamic> toJson() => {
    'next_cursor': nextCursor,
    'next_offset': nextOffset,
    'has_more': hasMore,
    'limit': limit,
    'offset': offset,
    'total_count': totalCount,
  };

  factory CollectionPagination.fromJson(Map<String, dynamic> json) {
    return CollectionPagination(
      nextCursor: json['next_cursor']?.toString(),
      nextOffset: (json['next_offset'] as num?)?.toInt(),
      hasMore: json['has_more'] == true,
      limit: (json['limit'] as num?)?.toInt() ?? 25,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CollectionDetail {
  const CollectionDetail({
    required this.collection,
    required this.reels,
    required this.pagination,
    this.canEdit = false,
    this.ownerName,
  });

  final CollectionSummary collection;
  final List<Reel> reels;
  final CollectionPagination pagination;
  final bool canEdit;
  final String? ownerName;

  /// Mirrors [fromJson] so a cached detail restores exactly as it arrived.
  Map<String, dynamic> toJson() => {
    'collection': collection.toJson(),
    'reels': reels.map((reel) => reel.toJson()).toList(),
    'pagination': pagination.toJson(),
    'can_edit': canEdit,
    'owner_name': ownerName,
  };

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final collectionPayload = json['collection'];
    final reelsPayload = json['reels'];
    final paginationPayload = json['pagination'];
    return CollectionDetail(
      collection: collectionPayload is Map<String, dynamic>
          ? CollectionSummary.fromJson(collectionPayload)
          : CollectionSummary.fromJson(json),
      reels: reelsPayload is List
          ? reelsPayload
                .whereType<Map>()
                .map((item) => Reel.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false)
          : const [],
      pagination: paginationPayload is Map<String, dynamic>
          ? CollectionPagination.fromJson(paginationPayload)
          : const CollectionPagination(),
      canEdit: json['can_edit'] == true,
      ownerName: json['owner_name']?.toString(),
    );
  }

  CollectionDetail append(CollectionDetail next) {
    return CollectionDetail(
      collection: next.collection,
      reels: [...reels, ...next.reels],
      pagination: next.pagination,
      canEdit: next.canEdit,
      ownerName: next.ownerName ?? ownerName,
    );
  }

  CollectionDetail copyWith({
    CollectionSummary? collection,
    List<Reel>? reels,
    CollectionPagination? pagination,
  }) {
    return CollectionDetail(
      collection: collection ?? this.collection,
      reels: reels ?? this.reels,
      pagination: pagination ?? this.pagination,
      canEdit: canEdit,
      ownerName: ownerName,
    );
  }
}

class CollectionMember {
  const CollectionMember({
    required this.userId,
    required this.role,
    this.createdAt,
    this.displayName,
  });

  final String userId;
  final String role;
  final String? createdAt;

  /// The name the account was created with. Null for accounts that have none,
  /// and for any build talking to an API that predates it.
  final String? displayName;

  /// What to put in front of a person: their name, or a short form of their id
  /// when there is no name to show. A full uuid tells the owner nothing.
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = userId.trim();
    return id.length > 8 ? 'USER ${id.substring(0, 8)}' : id;
  }

  factory CollectionMember.fromJson(Map<String, dynamic> json) {
    return CollectionMember(
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'viewer',
      createdAt: json['created_at']?.toString(),
      displayName: json['display_name']?.toString(),
    );
  }
}

class CollectionMembers {
  const CollectionMembers({required this.ownerId, this.members = const []});

  final String ownerId;
  final List<CollectionMember> members;

  factory CollectionMembers.fromJson(Map<String, dynamic> json) {
    final list = json['members'];
    return CollectionMembers(
      ownerId: json['owner_id']?.toString() ?? '',
      members: list is List
          ? list
                .whereType<Map>()
                .map(
                  (m) =>
                      CollectionMember.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class CollectionLink {
  const CollectionLink({required this.url, required this.token});

  final String url;
  final String token;

  factory CollectionLink.fromJson(Map<String, dynamic> json) {
    return CollectionLink(
      url: json['url']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }
}

class CollectionInvite {
  const CollectionInvite({
    required this.url,
    required this.token,
    required this.role,
    this.expiresAt,
  });

  final String url;
  final String token;
  final String role;
  final String? expiresAt;

  factory CollectionInvite.fromJson(Map<String, dynamic> json) {
    return CollectionInvite(
      url: json['url']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      role: json['role']?.toString() ?? 'viewer',
      expiresAt: json['expires_at']?.toString(),
    );
  }
}
