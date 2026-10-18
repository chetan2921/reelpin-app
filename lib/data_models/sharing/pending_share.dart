class PendingShare {
  const PendingShare({
    required this.rawPayloadText,
    this.collectionIds = const [],
  });

  final String rawPayloadText;
  final List<String> collectionIds;

  static PendingShare? fromNative(Object? value) {
    Object? payload = value;
    Object? ids;
    if (value is Map) {
      payload = value['raw_payload_text'];
      if (payload is! String || payload.trim().isEmpty) {
        payload = value['url'];
      }
      ids = value['collection_ids'];
    }
    if (payload is! String || payload.trim().isEmpty) return null;
    return PendingShare(
      rawPayloadText: payload.trim(),
      collectionIds: ids is List
          ? ids
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}
