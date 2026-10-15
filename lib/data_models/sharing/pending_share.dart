/// A share native code could not send, kept for the app to send on its next
/// launch or resume.
class PendingShare {
  const PendingShare({required this.payload, this.collectionIds = const []});

  final String payload;
  final List<String> collectionIds;

  /// Android stashes {raw_payload_text, collection_ids}; the iOS share
  /// extension stashes {url, collection_ids}. Anything already on disk from an
  /// older build is a bare string, and still has to drain. Returns null for an
  /// entry with nothing to send.
  static PendingShare? fromNative(Object? entry) {
    final blob =
        (entry is Map ? entry['raw_payload_text'] ?? entry['url'] : entry)
            ?.toString()
            .trim() ??
        '';
    if (blob.isEmpty) return null;
    final collectionIds = entry is Map
        ? (entry['collection_ids'] as List?)
                  ?.map((id) => id.toString())
                  .where((id) => id.isNotEmpty)
                  .toList(growable: false) ??
              const <String>[]
        : const <String>[];
    return PendingShare(payload: blob, collectionIds: collectionIds);
  }
}
