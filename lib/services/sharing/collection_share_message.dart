/// Builds the text that goes out when someone shares a collection.
///
/// Two jobs at once: tell the recipient what they are opening, and give anyone
/// who does not have ReelPin a reason to install it. Kept short because most of
/// these land in a chat app where long messages get collapsed.
class CollectionShareMessage {
  const CollectionShareMessage({required this.subject, required this.body});

  /// Used by mail clients and Android's EXTRA_SUBJECT; ignored elsewhere.
  final String subject;

  /// The shared text itself, link included.
  final String body;

  static const String _tagline =
      'Shared with ReelPin — save reels, posts and videos from anywhere, '
      'then actually find them again.';

  /// A read-only view link.
  factory CollectionShareMessage.forLink({
    required String collectionName,
    required String url,
    int itemCount = 0,
  }) {
    final name = _cleanName(collectionName);
    final count = itemCount > 0
        ? ' — $itemCount saved ${itemCount == 1 ? 'pin' : 'pins'}'
        : '';
    return CollectionShareMessage(
      subject: '$name on ReelPin',
      body:
          'Take a look at "$name"$count, all in one place.\n\n'
          '$url\n\n'
          '$_tagline',
    );
  }

  /// A collaborator invite. Leads with what the recipient can do, since an
  /// invite is a request to join rather than something to browse.
  factory CollectionShareMessage.forInvite({
    required String collectionName,
    required String url,
    required String role,
  }) {
    final name = _cleanName(collectionName);
    final canEdit = role == 'editor';
    final what = canEdit
        ? 'You can add and remove reels.'
        : 'You can browse everything inside.';
    return CollectionShareMessage(
      subject: 'Join "$name" on ReelPin',
      body:
          'You have been invited to "$name" on ReelPin. $what\n\n'
          '$url\n\n'
          '$_tagline',
    );
  }

  static String _cleanName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'this collection' : trimmed;
  }
}
