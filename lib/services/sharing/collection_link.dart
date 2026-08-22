/// A collection deep link: `/c/{token}` for a share link, `/c/invite/{token}`
/// for a collaborator invite.
///
/// Three places have to agree on this shape and they run at very different
/// times — the splash gate (before auth), the prefetch (before the shell
/// exists) and the shell (which opens the screen) — so the parse lives here
/// rather than being repeated at each of them.
class CollectionLink {
  const CollectionLink._(this.token, {required this.isInvite, this.url});

  final String token;
  final bool isInvite;

  /// The link exactly as it arrived, kept so a shared collection can pass it
  /// on when someone inside it shares a reel.
  final String? url;

  /// Returns null for any URL that is not a collection link, including a
  /// Linkrunner short link, which only becomes one after the SDK resolves it.
  static CollectionLink? parse(Uri uri) {
    final segments = _segments(uri);
    if (segments.isEmpty || segments.first != 'c') return null;
    if (segments.length >= 3 && segments[1] == 'invite') {
      return _of(segments[2], isInvite: true, url: uri.toString());
    }
    if (segments.length >= 2) {
      return _of(segments[1], isInvite: false, url: uri.toString());
    }
    return null;
  }

  /// The path segments to match on, with a custom scheme's host folded back in.
  ///
  /// `https://reelpin.in/c/invite/x` puts `c` in the path, but `reelpin://c/invite/x`
  /// puts it in the *host*, leaving the path as `invite/x`. The custom scheme is
  /// what a chat app's in-app browser can still open — those browsers never hand
  /// a Universal Link to the app — so both shapes have to reach the same place.
  static List<String> _segments(Uri uri) {
    if (uri.scheme == 'https' || uri.scheme == 'http') return uri.pathSegments;
    final host = uri.host;
    return host.isEmpty ? uri.pathSegments : [host, ...uri.pathSegments];
  }

  /// A trailing slash leaves an empty last segment, so `/c/` parses as far as a
  /// share link with no token. There is nothing to open, and it must not be
  /// mistaken for one: the splash hold and the prefetch both act on this.
  static CollectionLink? _of(
    String token, {
    required bool isInvite,
    String? url,
  }) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    return CollectionLink._(trimmed, isInvite: isInvite, url: url);
  }
}
