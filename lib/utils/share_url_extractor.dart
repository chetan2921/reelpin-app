class ShareUrlExtractor {
  ShareUrlExtractor._();

  static final _urlCandidateRegex = RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  );
  static final _videoIdRegex = RegExp(r'^[A-Za-z0-9_-]+$');
  static final _tiktokPathRegex = RegExp(r'^[A-Za-z0-9@._/-]+$');

  /// Pinterest runs a per-country domain (pinterest.ca, pinterest.co.uk,
  /// pinterest.com.au) and serves them from regional subdomains such as
  /// in.pinterest.com. Anchoring both ends keeps lookalikes like
  /// pinterest.com.example.com out.
  static final _pinterestHostRegex = RegExp(
    r'^(?:[a-z0-9-]+\.)*pinterest\.(?:com|net|info|[a-z]{2}|(?:com|co)\.[a-z]{2})$',
  );
  static const _trailingPunctuation = {
    '.',
    ',',
    '!',
    '?',
    ';',
    ':',
    ')',
    ']',
    '}',
    '"',
  };

  static String? extractSupportedUrl(String payload) {
    if (payload.trim().isEmpty) return null;
    for (final match in _urlCandidateRegex.allMatches(payload)) {
      final candidate = _trimTrailingPunctuation(match.group(0) ?? '');
      if (_isSupportedUrl(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static bool _isSupportedUrl(String value) {
    final uri = Uri.tryParse(value);
    final host = uri?.host.trim().toLowerCase() ?? '';
    if (uri == null || host.isEmpty) return false;

    return _isInstagramUrl(uri, host) ||
        _isTikTokUrl(uri, host) ||
        _isYoutubeUrl(uri, host) ||
        _isXUrl(host) ||
        _isPinterestUrl(host) ||
        _isRedditUrl(host) ||
        _isLinkedInUrl(host);
  }

  static bool _isInstagramUrl(Uri uri, String host) {
    if (host != 'instagram.com' && host != 'www.instagram.com') return false;
    final segments = uri.pathSegments;
    if (segments.length < 2) return false;

    final contentType = segments.first.toLowerCase();
    return (contentType == 'reel' ||
            contentType == 'p' ||
            contentType == 'tv') &&
        _videoIdRegex.hasMatch(segments[1]);
  }

  static bool _isTikTokUrl(Uri uri, String host) {
    if (host != 'tiktok.com' &&
        host != 'vt.tiktok.com' &&
        host != 'vm.tiktok.com') {
      return false;
    }
    final path = uri.path.replaceAll(RegExp(r'^/+|/+$'), '');
    return path.isNotEmpty && _tiktokPathRegex.hasMatch(path);
  }

  static bool _isYoutubeUrl(Uri uri, String host) {
    final segments = uri.pathSegments;
    if (host == 'youtu.be') {
      return segments.isNotEmpty && _videoIdRegex.hasMatch(segments.first);
    }
    if (host != 'youtube.com' &&
        host != 'www.youtube.com' &&
        host != 'm.youtube.com') {
      return false;
    }
    if (segments.length >= 2 &&
        segments.first.toLowerCase() == 'shorts' &&
        _videoIdRegex.hasMatch(segments[1])) {
      return true;
    }
    return uri.path.toLowerCase() == '/watch' &&
        _videoIdRegex.hasMatch(uri.queryParameters['v'] ?? '');
  }

  static bool _isXUrl(String host) {
    final normalizedHost = _withoutMobileOrWebPrefix(host);
    return normalizedHost == 'x.com' ||
        normalizedHost == 'twitter.com' ||
        normalizedHost == 't.co';
  }

  // Pinterest, Reddit, and LinkedIn are matched on host alone, the way X is:
  // the backend owns the path rules and returns a far better message than a
  // silent "no supported link found" from the share sheet.
  static bool _isPinterestUrl(String host) =>
      host == 'pin.it' || _pinterestHostRegex.hasMatch(host);

  static bool _isRedditUrl(String host) =>
      host == 'redd.it' || _isHostOrSubdomainOf(host, 'reddit.com');

  static bool _isLinkedInUrl(String host) =>
      _isHostOrSubdomainOf(host, 'linkedin.com');

  static bool _isHostOrSubdomainOf(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  static String _withoutMobileOrWebPrefix(String host) {
    for (final prefix in const ['www.', 'mobile.', 'm.']) {
      if (host.startsWith(prefix)) {
        return host.substring(prefix.length);
      }
    }
    return host;
  }

  static String _trimTrailingPunctuation(String value) {
    var end = value.length;
    while (end > 0 && _trailingPunctuation.contains(value[end - 1])) {
      end--;
    }
    return value.substring(0, end);
  }
}
