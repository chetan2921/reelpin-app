/// A collection deep link: `/c/{token}` for a share link, `/c/invite/{token}`
/// for a collaborator invite.
///
/// Three places have to agree on this shape and they run at very different
/// times — the splash gate (before auth), the prefetch (before the shell
/// exists) and the shell (which opens the screen) — so the parse lives here
/// rather than being repeated at each of them.
class CollectionLink {
  const CollectionLink._(this.token, {required this.isInvite});

  final String token;
  final bool isInvite;

  /// Returns null for any URL that is not a collection link, including a
  /// Linkrunner short link, which only becomes one after the SDK resolves it.
  static CollectionLink? parse(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty || segments.first != 'c') return null;
    if (segments.length >= 3 && segments[1] == 'invite') {
      return _of(segments[2], isInvite: true);
    }
    if (segments.length >= 2) {
      return _of(segments[1], isInvite: false);
    }
    return null;
  }

  /// A trailing slash leaves an empty last segment, so `/c/` parses as far as a
  /// share link with no token. There is nothing to open, and it must not be
  /// mistaken for one: the splash hold and the prefetch both act on this.
  static CollectionLink? _of(String token, {required bool isInvite}) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    return CollectionLink._(trimmed, isInvite: isInvite);
  }
}
