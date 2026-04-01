import 'dart:convert';

class Location {
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  const Location({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
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
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  /// Whether this location has valid coordinates for map pinning.
  bool get hasCoordinates => latitude != null && longitude != null;
}

class Reel {
  final String id;
  final String userId;
  final String url;
  final String title;
  final String summary;
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
  List<Location> get mappableLocations =>
      locations.where((l) => l.hasCoordinates).toList();

  /// Whether this reel has any map-pinnable locations.
  bool get hasMapLocations => mappableLocations.isNotEmpty;

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
}
