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
  final String? displayLabel;
  final String? googleMapsUrl;

  const Location({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.source,
    this.isDirectMention,
    this.isCaptionReference,
    this.isTranscriptReference,
    this.displayLabel,
    this.googleMapsUrl,
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
      name: json['name']?.toString() ?? json['location_name']?.toString() ?? '',
      address:
          json['address']?.toString() ?? json['location_address']?.toString(),
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
      displayLabel:
          json['location_display_label']?.toString() ??
          json['display_label']?.toString(),
      googleMapsUrl: json['google_maps_url']?.toString(),
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
    if (displayLabel != null) 'location_display_label': displayLabel,
    if (googleMapsUrl != null) 'google_maps_url': googleMapsUrl,
  };
}

class Reel {
  final String id;
  final String userId;
  final String url;
  final String sourceUrl;
  final String originalUrl;
  final String normalizedUrl;
  final String thumbnailUrl;
  final String title;
  final String summary;
  final String caption;
  final String transcript;
  final String category;
  final String subCategory;
  final String categoryLabel;
  final String subCategoryLabel;
  final String contentType;
  final String parseStatus;
  final String? sourcePlatform;
  final String? sourceContentType;
  final List<String> keyFacts;
  final List<Location> locations;
  final List<Location> mappableLocations;
  final List<String> peopleMentioned;
  final List<String> actionableItems;
  final String? createdAt;
  final String displayDate;
  final String relativeDate;
  final String savedDateKey;
  final bool hasMapLocations;
  final String primaryLocationLabel;
  final int mapLocationCount;

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
    this.sourceUrl = '',
    this.originalUrl = '',
    this.normalizedUrl = '',
    this.thumbnailUrl = '',
    this.categoryLabel = '',
    this.subCategoryLabel = '',
    this.contentType = 'post',
    this.parseStatus = 'parsed',
    this.sourcePlatform,
    this.sourceContentType,
    this.mappableLocations = const [],
    this.createdAt,
    this.displayDate = '',
    this.relativeDate = '',
    this.savedDateKey = '',
    this.hasMapLocations = false,
    this.primaryLocationLabel = '',
    this.mapLocationCount = 0,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    final locations = _parseLocations(json['locations']);
    final mappableLocations = _parseLocations(json['mappable_locations']);
    final category = json['category']?.toString() ?? 'Other';
    final subCategory =
        json['sub_category']?.toString() ??
        json['subcategory']?.toString() ??
        json['subCategory']?.toString() ??
        category;

    return Reel(
      id: json['id']?.toString() ?? json['reel_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      url:
          json['url']?.toString() ??
          json['reel_url']?.toString() ??
          json['permalink']?.toString() ??
          '',
      sourceUrl:
          json['source_url']?.toString() ??
          json['input_url']?.toString() ??
          json['submitted_url']?.toString() ??
          json['shared_url']?.toString() ??
          json['original_share_url']?.toString() ??
          '',
      originalUrl:
          json['original_url']?.toString() ??
          json['original_reel_url']?.toString() ??
          '',
      normalizedUrl:
          json['normalized_url']?.toString() ??
          json['canonical_url']?.toString() ??
          json['provider_url']?.toString() ??
          '',
      thumbnailUrl:
          json['thumbnail_url']?.toString() ??
          json['thumbnailUrl']?.toString() ??
          json['cover_url']?.toString() ??
          json['poster_url']?.toString() ??
          '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      caption:
          json['caption']?.toString() ??
          json['reel_caption']?.toString() ??
          json['video_caption']?.toString() ??
          '',
      transcript: _parseTranscript(json),
      category: category,
      subCategory: subCategory,
      categoryLabel: json['category_label']?.toString() ?? category,
      subCategoryLabel:
          json['sub_category_label']?.toString() ??
          json['subcategory_label']?.toString() ??
          subCategory,
      contentType: _normalizedContentType(json['content_type']),
      parseStatus: _normalizedParseStatus(json['parse_status']),
      sourcePlatform: _normalizedNullableString(json['source_platform']),
      sourceContentType: _normalizedNullableString(json['source_content_type']),
      keyFacts: _stringList(json['key_facts']),
      locations: locations,
      mappableLocations: mappableLocations,
      peopleMentioned: _stringList(json['people_mentioned']),
      actionableItems: _stringList(json['actionable_items']),
      createdAt: json['created_at']?.toString(),
      displayDate: json['display_date']?.toString() ?? '',
      relativeDate: json['relative_date']?.toString() ?? '',
      savedDateKey: json['saved_date_key']?.toString() ?? '',
      hasMapLocations: json['has_map_locations'] == true,
      primaryLocationLabel: json['primary_location_label']?.toString() ?? '',
      mapLocationCount: (json['map_location_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'url': url,
    'source_url': sourceUrl,
    'original_url': originalUrl,
    'normalized_url': normalizedUrl,
    'thumbnail_url': thumbnailUrl,
    'title': title,
    'summary': summary,
    'caption': caption,
    'transcript': transcript,
    'category': category,
    'sub_category': subCategory,
    'category_label': categoryLabel,
    'sub_category_label': subCategoryLabel,
    'content_type': contentType,
    'parse_status': parseStatus,
    if (sourcePlatform != null) 'source_platform': sourcePlatform,
    if (sourceContentType != null) 'source_content_type': sourceContentType,
    'key_facts': keyFacts,
    'locations': locations.map((l) => l.toJson()).toList(),
    'mappable_locations': mappableLocations.map((l) => l.toJson()).toList(),
    'people_mentioned': peopleMentioned,
    'actionable_items': actionableItems,
    if (createdAt != null) 'created_at': createdAt,
    'display_date': displayDate,
    'relative_date': relativeDate,
    'saved_date_key': savedDateKey,
    'has_map_locations': hasMapLocations,
    'primary_location_label': primaryLocationLabel,
    'map_location_count': mapLocationCount,
  };

  static List<Location> _parseLocations(dynamic raw) {
    if (raw is String) {
      try {
        return _parseLocations(jsonDecode(raw));
      } catch (_) {
        return const [];
      }
    }
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Location.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }
    return const [];
  }

  static String _parseTranscript(Map<String, dynamic> json) {
    const keys = [
      'transcript',
      'transcripts',
      'transcript_text',
      'transcription',
      'captions',
      'subtitles',
      'segments',
      'lines',
    ];

    for (final key in keys) {
      final value = _transcriptTextFromValue(json[key]).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String _transcriptTextFromValue(dynamic raw) {
    if (raw == null) {
      return '';
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) {
        return '';
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is List || decoded is Map) {
          final decodedText = _transcriptTextFromValue(decoded).trim();
          if (decodedText.isNotEmpty) {
            return decodedText;
          }
        }
      } catch (_) {
        // The value is already plain transcript text.
      }
      return value;
    }
    if (raw is List) {
      return raw
          .map(_transcriptTextFromValue)
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    if (raw is Map) {
      const keys = [
        'text',
        'transcript',
        'transcripts',
        'transcript_text',
        'transcription',
        'segment',
        'segments',
        'caption',
        'captions',
        'subtitle',
        'subtitles',
        'line',
        'lines',
        'value',
        'content',
      ];
      for (final key in keys) {
        final value = _transcriptTextFromValue(raw[key]).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }
    return raw.toString().trim();
  }

  bool get isUnparsed => parseStatus == 'unparsed';

  static String _normalizedContentType(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'reel' => 'reel',
      'carousel' => 'carousel',
      _ => 'post',
    };
  }

  static String _normalizedParseStatus(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    return value == 'unparsed' ? 'unparsed' : 'parsed';
  }

  static String? _normalizedNullableString(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    return value == null || value.isEmpty ? null : value;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is String) {
      try {
        return _stringList(jsonDecode(raw));
      } catch (_) {
        final value = raw.trim();
        return value.isEmpty ? const [] : [value];
      }
    }
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
