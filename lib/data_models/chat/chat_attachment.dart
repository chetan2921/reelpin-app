enum AttachmentKind { photo, camera, file, savedReel, link, collection }

/// A short, human word for the kind — chips show this ahead of the
/// attachment's own name ("COLLECTION · ROAD TRIP") so it's clear at a
/// glance what was attached, not just its name.
extension AttachmentKindLabel on AttachmentKind {
  String get label => switch (this) {
    AttachmentKind.photo => 'Photo',
    AttachmentKind.camera => 'Photo',
    AttachmentKind.file => 'File',
    AttachmentKind.savedReel => 'Save',
    AttachmentKind.link => 'Link',
    AttachmentKind.collection => 'Collection',
  };
}

/// Anything the user adds to a question. New sources are a new enum value plus
/// one row in the attachment sheet — the rest of the pipeline is unchanged.
class ChatAttachment {
  final AttachmentKind kind;
  final String displayName;

  /// Set for photo, camera and file.
  final String? localPath;

  /// Set for link.
  final String? url;

  /// Set for savedReel.
  final String? reelId;

  /// Set for collection. Scopes retrieval to that collection's reels rather
  /// than the user's whole library.
  final String? collectionId;

  const ChatAttachment({
    required this.kind,
    required this.displayName,
    this.localPath,
    this.url,
    this.reelId,
    this.collectionId,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    kind: AttachmentKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => AttachmentKind.file,
    ),
    displayName: json['display_name']?.toString() ?? '',
    localPath: json['local_path']?.toString(),
    url: json['url']?.toString(),
    reelId: json['reel_id']?.toString(),
    collectionId: json['collection_id']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'display_name': displayName,
    if (localPath != null) 'local_path': localPath,
    if (url != null) 'url': url,
    if (reelId != null) 'reel_id': reelId,
    if (collectionId != null) 'collection_id': collectionId,
  };
}
