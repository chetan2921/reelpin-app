/// One piece of an assistant answer. An answer is a list of these rather than
/// a string, so the renderer is an exhaustive switch and adding a sixth kind
/// later is a compile error at every site that must handle it.
sealed class AnswerBlock {
  const AnswerBlock();

  Map<String, dynamic> toJson();

  /// Returns null for a block type this build does not know, so a thread
  /// written by a newer build still opens here with its other blocks intact.
  static AnswerBlock? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return TextBlock(json['text']?.toString() ?? '');
      case 'reel_refs':
        return ReelRefsBlock(_stringList(json['reel_ids']));
      case 'places':
        return PlacesBlock(
          _mapList(json['places']).map(AnswerPlace.fromJson).toList(),
        );
      case 'table':
        return TableBlock(
          columns: _stringList(json['columns']),
          rows: _listOfStringLists(json['rows']),
        );
      case 'chart':
        return ChartBlock(
          title: json['title']?.toString() ?? '',
          bars: _mapList(json['bars']).map(ChartBar.fromJson).toList(),
        );
      default:
        return null;
    }
  }
}

/// A field holding the wrong JSON type (a String where a List was expected,
/// say) degrades to an empty value here rather than throwing, so one bad
/// field never takes the rest of the block — or the thread — down with it.
List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((item) => item.toString()).toList();
}

List<Map<String, dynamic>> _mapList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

List<List<String>> _listOfStringLists(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<List>()
      .map((row) => row.map((cell) => cell.toString()).toList())
      .toList();
}

double _asDouble(dynamic raw, [double fallback = 0]) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? fallback;
  return fallback;
}

class TextBlock extends AnswerBlock {
  final String text;

  const TextBlock(this.text);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

/// Ids only. The cards are rendered from whatever the library currently holds,
/// so a reel edited or deleted after the answer was written does not leave a
/// stale copy of itself inside the thread.
class ReelRefsBlock extends AnswerBlock {
  final List<String> reelIds;

  const ReelRefsBlock(this.reelIds);

  @override
  Map<String, dynamic> toJson() => {'type': 'reel_refs', 'reel_ids': reelIds};
}

class PlacesBlock extends AnswerBlock {
  final List<AnswerPlace> places;

  const PlacesBlock(this.places);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'places',
    'places': places.map((p) => p.toJson()).toList(),
  };
}

class TableBlock extends AnswerBlock {
  final List<String> columns;
  final List<List<String>> rows;

  const TableBlock({required this.columns, required this.rows});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'table',
    'columns': columns,
    'rows': rows,
  };
}

class ChartBlock extends AnswerBlock {
  final String title;
  final List<ChartBar> bars;

  const ChartBlock({required this.title, required this.bars});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'chart',
    'title': title,
    'bars': bars.map((b) => b.toJson()).toList(),
  };
}

class AnswerPlace {
  final String name;
  final double latitude;
  final double longitude;

  /// Drives the marker colour through AppColors.getCategoryColor, so a place
  /// is the same colour here as on the Map tab.
  final String category;
  final String? reelId;

  const AnswerPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.reelId,
  });

  factory AnswerPlace.fromJson(Map<String, dynamic> json) => AnswerPlace(
    name: json['name']?.toString() ?? '',
    latitude: _asDouble(json['latitude']),
    longitude: _asDouble(json['longitude']),
    category: json['category']?.toString() ?? 'Other',
    reelId: json['reel_id']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'category': category,
    if (reelId != null) 'reel_id': reelId,
  };
}

class ChartBar {
  final String label;
  final double value;
  final String category;

  const ChartBar({
    required this.label,
    required this.value,
    required this.category,
  });

  factory ChartBar.fromJson(Map<String, dynamic> json) => ChartBar(
    label: json['label']?.toString() ?? '',
    value: _asDouble(json['value']),
    category: json['category']?.toString() ?? 'Other',
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'category': category,
  };
}
