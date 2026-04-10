import 'dart:convert';

import 'reel.dart';

class RecallRegion {
  const RecallRegion({
    required this.id,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.reelIds,
    required this.reelTitles,
    required this.categories,
    this.address,
  });

  final String id;
  final String locationName;
  final String? address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final List<String> reelIds;
  final List<String> reelTitles;
  final List<String> categories;

  int get reelCount => reelIds.length;

  String get primaryCategory =>
      categories.isNotEmpty ? categories.first : 'Saved Reels';

  factory RecallRegion.fromJson(Map<String, dynamic> json) {
    return RecallRegion(
      id: json['id'] as String,
      locationName: json['location_name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      reelIds: List<String>.from(json['reel_ids'] ?? const []),
      reelTitles: List<String>.from(json['reel_titles'] ?? const []),
      categories: List<String>.from(json['categories'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'location_name': locationName,
    if (address != null) 'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'radius_meters': radiusMeters,
    'reel_ids': reelIds,
    'reel_titles': reelTitles,
    'categories': categories,
  };

  static String encodeList(List<RecallRegion> regions) =>
      jsonEncode(regions.map((region) => region.toJson()).toList());

  static List<RecallRegion> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => RecallRegion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static List<RecallRegion> fromReels(List<Reel> reels) {
    final grouped = <String, _RecallAccumulator>{};

    for (final reel in reels) {
      for (final location in reel.mappableLocations) {
        final key =
            '${location.latitude!.toStringAsFixed(5)}_${location.longitude!.toStringAsFixed(5)}_${location.name.toLowerCase()}';

        final accumulator = grouped.putIfAbsent(
          key,
          () => _RecallAccumulator(location),
        );
        accumulator.addReel(reel);
      }
    }

    return grouped.values
        .map((accumulator) => accumulator.build())
        .toList()
      ..sort((a, b) => b.reelCount.compareTo(a.reelCount));
  }
}

class _RecallAccumulator {
  _RecallAccumulator(this.location);

  final Location location;
  final Set<String> reelIds = <String>{};
  final Set<String> reelTitles = <String>{};
  final Set<String> categories = <String>{};

  void addReel(Reel reel) {
    reelIds.add(reel.id);
    if (reel.title.trim().isNotEmpty) {
      reelTitles.add(reel.title.trim());
    }
    if (reel.subCategory.trim().isNotEmpty) {
      categories.add(reel.subCategory.trim());
    } else if (reel.category.trim().isNotEmpty) {
      categories.add(reel.category.trim());
    }
  }

  RecallRegion build() {
    return RecallRegion(
      id:
          'recall_${location.latitude!.toStringAsFixed(5)}_${location.longitude!.toStringAsFixed(5)}',
      locationName: location.name,
      address: location.address,
      latitude: location.latitude!,
      longitude: location.longitude!,
      radiusMeters: 150,
      reelIds: reelIds.toList(),
      reelTitles: reelTitles.toList(),
      categories: categories.toList(),
    );
  }
}
