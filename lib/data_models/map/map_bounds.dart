/// A map viewport. A [west] greater than [east] is a box that crosses the
/// antimeridian; the backend splits it in two, so it is sent unchanged.
class MapBounds {
  const MapBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  static const world = MapBounds(south: -90, west: -180, north: 90, east: 180);

  final double south;
  final double west;
  final double north;
  final double east;

  /// The backend answers 422 for a box with no height, which is what a map
  /// reports before it has been laid out.
  bool get hasArea => south < north;

  Map<String, String> toQueryParameters() => {
    'south': south.toString(),
    'west': west.toString(),
    'north': north.toString(),
    'east': east.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is MapBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}
