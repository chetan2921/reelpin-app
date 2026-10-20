import 'package:reelpin/data_models/reels/reel.dart';

class CollectionSummary {
  const CollectionSummary({
    required this.id,
    required this.name,
    this.webUrl = '',
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
  final String webUrl;
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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      webUrl: json['web_url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverReelId: json['cover_reel_id']?.toString(),
      visibility: json['visibility']?.toString() ?? 'private',
      role: json['role']?.toString() ?? 'owner',
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  /// Mirrors [fromJson] so a cached grid restores exactly as it arrived.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'web_url': webUrl,
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
      webUrl: webUrl,
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
  const CollectionPagination({this.nextCursor, this.limit = 25});

  final String? nextCursor;
  final int limit;

  bool get hasMore => nextCursor != null;

  /// Mirrors [fromJson] so a cached detail restores exactly as it arrived.
  Map<String, dynamic> toJson() => {
    'next_cursor': nextCursor,
    'has_more': hasMore,
    'limit': limit,
  };

  factory CollectionPagination.fromJson(Map<String, dynamic> json) {
    return CollectionPagination(
      nextCursor: json['next_cursor']?.toString(),
      limit: (json['limit'] as num?)?.toInt() ?? 25,
    );
  }
}

class CollectionDetail {
  const CollectionDetail({
    required this.collection,
    required this.reels,
    required this.pagination,
    this.canEdit = false,
  });

  final CollectionSummary collection;

  /// The collection's items. The API sends cards (id, title, summary, links,
  /// thumbnail, platform), not full reels, so everything else on these is a
  /// default until the reel itself is fetched.
  final List<Reel> reels;
  final CollectionPagination pagination;
  final bool canEdit;

  /// Mirrors [fromJson] so a cached detail restores exactly as it arrived.
  Map<String, dynamic> toJson() => {
    'collection': collection.toJson(),
    'items': reels.map(_itemFromReel).toList(),
    'page': pagination.toJson(),
    'can_edit': canEdit,
  };

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final itemsPayload = json['items'];
    final pagePayload = json['page'];
    return CollectionDetail(
      collection: CollectionSummary.fromJson(
        Map<String, dynamic>.from(json['collection'] as Map? ?? const {}),
      ),
      reels: itemsPayload is List
          ? itemsPayload
                .whereType<Map>()
                .map((item) => _reelFromItem(Map<String, dynamic>.from(item)))
                .toList(growable: false)
          : const [],
      pagination: pagePayload is Map<String, dynamic>
          ? CollectionPagination.fromJson(pagePayload)
          : const CollectionPagination(),
      canEdit: json['can_edit'] == true,
    );
  }

  CollectionDetail append(CollectionDetail next) {
    return CollectionDetail(
      collection: next.collection,
      reels: [...reels, ...next.reels],
      pagination: next.pagination,
      canEdit: next.canEdit,
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
    );
  }

  static Reel _reelFromItem(Map<String, dynamic> json) {
    final sourcePlatform = json['source_platform']?.toString().trim();
    return Reel(
      id: json['reel_id']?.toString() ?? '',
      userId: '',
      url: json['url']?.toString() ?? '',
      webUrl: json['web_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      caption: '',
      transcript: '',
      category: 'Other',
      subCategory: 'Other',
      sourcePlatform: sourcePlatform == null || sourcePlatform.isEmpty
          ? null
          : sourcePlatform,
      createdAt: json['saved_at']?.toString(),
      keyFacts: const [],
      locations: const [],
      peopleMentioned: const [],
      actionableItems: const [],
    );
  }

  static Map<String, dynamic> _itemFromReel(Reel reel) => {
    'reel_id': reel.id,
    'title': reel.title,
    'summary': reel.summary,
    'url': reel.url,
    'web_url': reel.webUrl,
    'thumbnail_url': reel.thumbnailUrl,
    'source_platform': reel.sourcePlatform,
    'saved_at': reel.createdAt,
  };
}

class CollectionMember {
  const CollectionMember({
    required this.userId,
    required this.role,
    this.createdAt,
  });

  final String userId;
  final String role;
  final String? createdAt;

  /// The API sends no names, so a person is a short form of their id. A full
  /// uuid tells the owner nothing.
  String get label {
    final id = userId.trim();
    return id.length > 8 ? 'USER ${id.substring(0, 8)}' : id;
  }

  factory CollectionMember.fromJson(Map<String, dynamic> json) {
    return CollectionMember(
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'viewer',
      createdAt: json['created_at']?.toString(),
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
