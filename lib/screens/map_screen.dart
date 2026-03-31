import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/reel.dart';
import '../theme/app_theme.dart';
import '../viewmodels/map_viewmodel.dart';
import '../widgets/category_badge.dart';
import 'reel_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Default to Bangalore center
  static const _defaultLatLng = LatLng(12.9716, 77.5946);

  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _categoryMarkers = {};

  int _lastMarkersCount = -1;
  String? _lastCategoryFilter;
  bool _isDarkMap = true;

  @override
  void initState() {
    super.initState();
    _initCustomMarkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MapViewModel>().loadMapReels(forceRefresh: true);
      }
    });
  }

  Future<void> _initCustomMarkers() async {
    for (final cat in ApiConfig.allCategories) {
      _categoryMarkers[cat] = await _createCustomPin(cat);
    }
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createCustomPin(String category) async {
    final color = AppTheme.getCategoryColor(category);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(50, 65);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = AppTheme.midnightPlum.withAlpha(90)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(size.width / 2, size.height); // bottom tip
    path.quadraticBezierTo(
      0,
      size.height * 0.6,
      0,
      size.width / 2,
    ); // left curve
    path.arcToPoint(
      Offset(size.width, size.width / 2),
      radius: Radius.circular(size.width / 2),
      clockwise: true,
    ); // top arc
    path.quadraticBezierTo(
      size.width,
      size.height * 0.6,
      size.width / 2,
      size.height,
    ); // right curve

    canvas.save();
    canvas.translate(0, 6);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw main pin body
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Draw subtle gradient ring
    final ringPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [AppTheme.cream.withAlpha(80), Colors.transparent],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, ringPaint);

    // Draw inner circle
    canvas.drawCircle(
      Offset(size.width / 2, size.width / 2),
      size.width * 0.38,
      Paint()..color = AppTheme.midnightPlum,
    );

    // Draw initial of category
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: category.isNotEmpty ? category[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppTheme.cream,
        fontFamily: 'Poppins',
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.width / 2) - (textPainter.height / 2),
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _fitMarkers(Set<Marker> markers) {
    if (_mapController == null || markers.isEmpty) return;

    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final m in markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Provide padding depending on whether one or multiple pins exist
    final padding = markers.length == 1 ? 20.0 : 40.0;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightPlum,
      body: SafeArea(
        bottom: false,
        child: Consumer<MapViewModel>(
          builder: (context, vm, _) {
            final markers = _buildMarkers(vm);

            // Trigger bound fitting when markers change
            if ((markers.length != _lastMarkersCount ||
                    vm.selectedCategory != _lastCategoryFilter) &&
                markers.isNotEmpty) {
              _lastMarkersCount = markers.length;
              _lastCategoryFilter = vm.selectedCategory;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fitMarkers(markers);
              });
            }

            return Stack(
              children: [
                // ── Google Map ──
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _defaultLatLng,
                    zoom: 12,
                  ),
                  markers: markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (markers.isNotEmpty) {
                      _fitMarkers(markers);
                    }
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: _isDarkMap ? _purpleMapStyle : null,
                ),

                // ── Header overlay ──
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      // Title bar — glass effect
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.deepIndigo.withAlpha(200),
                                  AppTheme.amethyst.withAlpha(120),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.cream.withAlpha(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.accentGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.map_rounded,
                                    color: AppTheme.cream,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Pinned Locations',
                                  style: TextStyle(
                                    color: AppTheme.cream,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mauve.withAlpha(60),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${vm.reelsWithLocations.length} pins',
                                    style: TextStyle(
                                      color: AppTheme.dustyRose,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Dark Mode Toggle
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _isDarkMap = !_isDarkMap),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mauve.withAlpha(
                                        _isDarkMap ? 80 : 30,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _isDarkMap
                                          ? Icons.dark_mode_rounded
                                          : Icons.light_mode_rounded,
                                      size: 16,
                                      color: AppTheme.cream.withAlpha(200),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category filters
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ApiConfig.broadCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final cat = ApiConfig.broadCategories[i];
                            return CategoryBadge(
                              category: cat,
                              isSelected: vm.selectedCategory == cat,
                              onTap: () => vm.filterByCategory(cat),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Loading ──
                if (vm.isLoading)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.deepIndigo.withAlpha(200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const CircularProgressIndicator(
                        color: AppTheme.dustyRose,
                      ),
                    ),
                  ),

                // ── Empty overlay ──
                if (!vm.isLoading && vm.reelsWithLocations.isEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.deepIndigo.withAlpha(220),
                                AppTheme.amethyst.withAlpha(140),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.cream.withAlpha(20),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.mauve.withAlpha(50),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.location_off_rounded,
                                  size: 28,
                                  color: AppTheme.dustyRose.withAlpha(180),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No pinned locations yet',
                                style: TextStyle(
                                  color: AppTheme.cream.withAlpha(200),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Save reels with locations to see them here',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.cream.withAlpha(90),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Selected reel bottom sheet ──
                if (vm.selectedReel != null)
                  Positioned(
                    bottom: 108,
                    left: 16,
                    right: 16,
                    child: _buildPinSheet(context, vm.selectedReel!),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(MapViewModel vm) {
    final markers = <Marker>{};
    for (final reel in vm.reelsWithLocations) {
      for (final loc in reel.mappableLocations) {
        markers.add(
          Marker(
            markerId: MarkerId('${reel.id}_${loc.name}'),
            position: LatLng(loc.latitude!, loc.longitude!),
            infoWindow: InfoWindow(title: reel.title, snippet: loc.name),
            icon:
                _categoryMarkers[reel.category] ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            onTap: () => vm.selectReel(reel),
          ),
        );
      }
    }
    return markers;
  }

  Widget _buildPinSheet(BuildContext context, Reel reel) {
    final catColor = AppTheme.getCategoryColor(reel.category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.deepIndigo.withAlpha(220),
                AppTheme.amethyst.withAlpha(140),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: catColor.withAlpha(60)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.midnightPlum.withAlpha(120),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header line
              Row(
                children: [
                  CategoryBadge(category: reel.category, small: true),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.read<MapViewModel>().selectReel(null),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.cream.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppTheme.cream.withAlpha(140),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                reel.title,
                style: TextStyle(
                  color: AppTheme.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Summary
              if (reel.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  reel.summary,
                  style: TextStyle(
                    color: AppTheme.cream.withAlpha(130),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Location Text
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: catColor.withAlpha(200),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reel.locations.map((l) => l.name).join(' • '),
                      style: TextStyle(
                        color: AppTheme.cream.withAlpha(90),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  // View Details Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReelDetailScreen(reel: reel),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.deepIndigo.withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.cream.withAlpha(15),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            color: AppTheme.cream.withAlpha(200),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Navigate Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final loc = reel.mappableLocations.first;
                        final queryParam = loc.name.isNotEmpty
                            ? Uri.encodeComponent(loc.name)
                            : '${loc.latitude},${loc.longitude}';

                        final url =
                            'https://www.google.com/maps/search/?api=1&query=$queryParam';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mauve.withAlpha(60),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions,
                              size: 16,
                              color: AppTheme.cream,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Navigate',
                              style: TextStyle(
                                color: AppTheme.cream,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Purple-toned dark map style ──
  static const String _purpleMapStyle = '''[
  {"elementType": "geometry", "stylers": [{"color": "#1a0a2e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#9b8bb4"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a0a2e"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#3d2060"}]},
  {"featureType": "land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#6b5880"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#241540"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#7a6890"}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#1e1038"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2d1a4a"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8b7aa0"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3d2060"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#8b7aa0"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#120828"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4a3865"}]}
]''';
}
