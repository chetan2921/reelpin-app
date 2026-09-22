/// Builds a Google Maps search URL for a named place, so a location card can
/// hand off to the user's own Maps app instead of embedding a map to pan.
Uri? locationMapsSearchUri({
  String? name,
  String? displayLabel,
  String? address,
  String? backendUrl,
  double? latitude,
  double? longitude,
}) {
  final placeQuery = _firstNonEmpty([name, displayLabel, address]);
  if (placeQuery != null) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(placeQuery)}',
    );
  }

  final fallbackUri = _externalLocationUri(backendUrl);
  if (fallbackUri != null) {
    return fallbackUri;
  }

  if (latitude != null && longitude != null) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
  }
  return null;
}

Uri? _externalLocationUri(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.trim().isEmpty) return null;
  return uri;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
