import 'dart:convert';

class Location {
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? source;
  final bool? isDirectMention;
  final bool? isCaptionReference;
  final bool? isTranscriptReference;

  const Location({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.source,
    this.isDirectMention,
    this.isCaptionReference,
    this.isTranscriptReference,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    return Location(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      latitude: parseCoord(json['latitude']) ?? parseCoord(json['lat']),
      longitude:
          parseCoord(json['longitude']) ??
          parseCoord(json['lng']) ??
          parseCoord(json['lon']),
      source:
          json['source']?.toString() ??
          json['location_source']?.toString() ??
          json['mention_source']?.toString(),
      isDirectMention: parseBool(
        json['is_direct_mention'] ??
            json['direct_mention'] ??
            json['mentioned_directly'],
      ),
      isCaptionReference: parseBool(
        json['mentioned_in_caption'] ??
            json['caption_reference'] ??
            json['from_caption'],
      ),
      isTranscriptReference: parseBool(
        json['mentioned_in_transcript'] ??
            json['transcript_reference'] ??
            json['from_transcript'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (source != null) 'source': source,
    if (isDirectMention != null) 'is_direct_mention': isDirectMention,
    if (isCaptionReference != null) 'mentioned_in_caption': isCaptionReference,
    if (isTranscriptReference != null)
      'mentioned_in_transcript': isTranscriptReference,
  };

  /// Whether this location has valid coordinates for map pinning.
  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasExplicitMentionSignal {
    final normalizedSource = source?.trim().toLowerCase();
    return isDirectMention == true ||
        isCaptionReference == true ||
        isTranscriptReference == true ||
        normalizedSource == 'caption' ||
        normalizedSource == 'transcript' ||
        normalizedSource == 'direct' ||
        normalizedSource == 'mentioned';
  }
}

class Reel {
  final String id;
  final String userId;
  final String url;
  final String title;
  final String summary;
  final String caption;
  final String transcript;
  final String category;
  final String subCategory;
  final List<String> keyFacts;
  final List<Location> locations;
  final List<String> peopleMentioned;
  final List<String> actionableItems;
  final String? createdAt;

  const Reel({
    required this.id,
    required this.userId,
    required this.url,
    required this.title,
    required this.summary,
    required this.caption,
    required this.transcript,
    required this.category,
    required this.subCategory,
    required this.keyFacts,
    required this.locations,
    required this.peopleMentioned,
    required this.actionableItems,
    this.createdAt,
  });

  factory Reel.fromJson(Map<String, dynamic> json) => Reel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    url: json['url'] as String,
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    caption:
        json['caption'] as String? ??
        json['reel_caption'] as String? ??
        json['video_caption'] as String? ??
        '',
    transcript: json['transcript'] as String? ?? '',
    category: json['category'] as String? ?? 'Other',
    subCategory:
        json['sub_category'] as String? ??
        json['subcategory'] as String? ??
        json['subCategory'] as String? ??
        json['category'] as String? ??
        'Other',
    keyFacts: List<String>.from(json['key_facts'] ?? []),
    locations: () {
      final locs = json['locations'];
      if (locs is String) {
        try {
          return (jsonDecode(locs) as List<dynamic>)
              .map((l) => Location.fromJson(l as Map<String, dynamic>))
              .toList();
        } catch (_) {
          return <Location>[];
        }
      } else if (locs is List) {
        return locs
            .map((l) => Location.fromJson(l as Map<String, dynamic>))
            .toList();
      }
      return <Location>[];
    }(),
    peopleMentioned: List<String>.from(json['people_mentioned'] ?? []),
    actionableItems: List<String>.from(json['actionable_items'] ?? []),
    createdAt: json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'url': url,
    'title': title,
    'summary': summary,
    'caption': caption,
    'transcript': transcript,
    'category': category,
    'sub_category': subCategory,
    'key_facts': keyFacts,
    'locations': locations.map((l) => l.toJson()).toList(),
    'people_mentioned': peopleMentioned,
    'actionable_items': actionableItems,
    if (createdAt != null) 'created_at': createdAt,
  };

  /// All locations that can be pinned on a map.
  List<Location> get mappableLocations {
    final candidates = locations
        .where((location) => location.hasCoordinates)
        .toList();
    if (candidates.isEmpty) {
      return const [];
    }

    final matches = candidates.where(_shouldPinLocation).toList();
    if (matches.isNotEmpty) {
      return matches;
    }

    // If the backend only extracted a small set of coordinates, keep them
    // instead of dropping the reel entirely when text matching is imperfect.
    if (candidates.length <= 2) {
      return candidates;
    }

    return candidates.where(_isSpecificFallbackLocation).take(2).toList();
  }

  /// Whether this reel has any map-pinnable locations.
  bool get hasMapLocations => mappableLocations.isNotEmpty;

  bool _shouldPinLocation(Location location) {
    if (location.hasExplicitMentionSignal) {
      return true;
    }

    final searchableText = _normalizedMapSourceText;
    if (searchableText.isEmpty) {
      return false;
    }

    return _matchableLocationPhrases(location).any(
      (phrase) =>
          _containsNormalizedPhrase(searchableText, phrase) ||
          _containsMeaningfulTokenMatch(searchableText, phrase),
    );
  }

  Iterable<String> _matchableLocationPhrases(Location location) sync* {
    if (location.name.trim().isNotEmpty) {
      yield location.name;
    }

    final address = location.address?.trim();
    if (address != null && address.isNotEmpty) {
      yield address;

      final leadSegment = address.split(',').first.trim();
      if (leadSegment.isNotEmpty && leadSegment != address) {
        yield leadSegment;
      }
    }
  }

  String get _normalizedMapSourceText => _normalizeMatchText(
    [
      title,
      caption,
      transcript,
      summary,
      keyFacts.join(' '),
      actionableItems.join(' '),
    ].where((part) => part.trim().isNotEmpty).join(' '),
  );

  bool _containsNormalizedPhrase(String haystack, String needle) {
    final normalizedNeedle = _normalizeMatchText(needle);
    if (normalizedNeedle.isEmpty) {
      return false;
    }
    return ' $haystack '.contains(' $normalizedNeedle ');
  }

  bool _containsMeaningfulTokenMatch(String haystack, String phrase) {
    final tokens = _normalizeMatchText(phrase)
        .split(' ')
        .where(
          (token) =>
              token.isNotEmpty &&
              (token.length >= 4 || RegExp(r'\d').hasMatch(token)),
        )
        .toList();

    if (tokens.isEmpty) {
      return false;
    }

    final matched = tokens
        .where((token) => ' $haystack '.contains(' $token '))
        .length;

    if (tokens.length == 1) {
      return matched == 1;
    }

    return matched >= 2;
  }

  bool _isSpecificFallbackLocation(Location location) {
    final normalizedName = _normalizeMatchText(location.name);
    if (normalizedName.isEmpty) {
      return false;
    }

    final tokenCount = normalizedName
        .split(' ')
        .where((t) => t.isNotEmpty)
        .length;
    return tokenCount >= 2 ||
        (location.address != null && location.address!.trim().isNotEmpty);
  }

  String _normalizeMatchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Formatted date string for display.
  String get displayDate {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt!);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return createdAt!;
    }
  }

  /// Human-friendly relative time string.
  String get relativeDate {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt!);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return displayDate;
    }
  }
}
