/// The platforms ReelPin can save from, keyed by the `source_platform` value
/// the backend stores on a reel.
///
/// Onboarding, the home hint, the card badge, and the detail screen all read
/// from [SourcePlatform.all] so a new platform only has to be added once and
/// the copy for it cannot drift between screens.
class SourcePlatform {
  const SourcePlatform._({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.savedItemNoun,
    required this.openSourceNoun,
  });

  /// Matches `source_platform` on the reel payload.
  final String id;

  /// Title-case name, used for semantics labels.
  final String name;

  final String assetPath;

  /// What a single save from this platform is called in copy, e.g.
  /// "DELETE THIS REEL?" versus "DELETE THIS PIN?".
  final String savedItemNoun;

  /// Noun for the "OPEN …" action on the detail screen. The detail screen
  /// refines this per content type where it can (Shorts vs video, post vs
  /// reel); this is the fallback when the content type is unknown.
  final String openSourceNoun;

  /// Upper-case name, matching the app's shouty display copy.
  String get label => name.toUpperCase();

  static const instagram = SourcePlatform._(
    id: 'instagram',
    name: 'Instagram',
    assetPath: 'assets/images/instagram.png',
    savedItemNoun: 'REEL',
    openSourceNoun: 'REEL',
  );

  static const youtube = SourcePlatform._(
    id: 'youtube',
    name: 'YouTube',
    assetPath: 'assets/images/youtube.png',
    savedItemNoun: 'REEL',
    openSourceNoun: 'VIDEO',
  );

  static const x = SourcePlatform._(
    id: 'x',
    name: 'X',
    assetPath: 'assets/images/twitter.png',
    savedItemNoun: 'POST',
    openSourceNoun: 'X POST',
  );

  static const pinterest = SourcePlatform._(
    id: 'pinterest',
    name: 'Pinterest',
    assetPath: 'assets/images/pinterest.png',
    savedItemNoun: 'PIN',
    openSourceNoun: 'PIN',
  );

  static const reddit = SourcePlatform._(
    id: 'reddit',
    name: 'Reddit',
    assetPath: 'assets/images/reddit.png',
    savedItemNoun: 'POST',
    openSourceNoun: 'REDDIT POST',
  );

  static const linkedin = SourcePlatform._(
    id: 'linkedin',
    name: 'LinkedIn',
    assetPath: 'assets/images/linkedin.png',
    savedItemNoun: 'POST',
    openSourceNoun: 'LINKEDIN POST',
  );

  /// Display order for every surface that lists the supported platforms.
  static const List<SourcePlatform> all = [
    instagram,
    youtube,
    x,
    pinterest,
    reddit,
    linkedin,
  ];

  /// Resolves a backend `source_platform` value. Returns null for anything the
  /// app has no artwork or copy for, so callers can fall back to neutral text
  /// instead of showing a wrong platform.
  static SourcePlatform? byId(String? id) {
    final normalized = id?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final platform in all) {
      if (platform.id == normalized) return platform;
    }
    return null;
  }
}
