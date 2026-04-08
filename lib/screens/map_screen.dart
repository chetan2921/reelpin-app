import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/reel.dart';
import '../services/location_service.dart';
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
  static const _defaultLatLng = LatLng(20.0, 0.0);

  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _categoryMarkers = {};
  LatLng? _userLatLng;
  String? _userCountry;
  bool _hasCenteredOnCountry = false;

  int _lastMarkersCount = -1;
  String? _lastCategoryFilter;

  @override
  void initState() {
    super.initState();
    _initCustomMarkers();
    _initUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MapViewModel>().loadMapReels(forceRefresh: true);
      }
    });
  }

  Future<void> _initUserLocation() async {
    final position = await LocationService.instance
        .getCurrentOrLastKnownLocation(requestPermissionIfNeeded: true);

    if (!mounted || position == null) return;

    _userLatLng = LatLng(position.latitude, position.longitude);
    await _resolveUserCountry(position.latitude, position.longitude);
    _centerMapOnUserCountry();
  }

  Future<void> _resolveUserCountry(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isNotEmpty && mounted) {
        setState(() {
          _userCountry = places.first.country;
        });
      }
    } catch (_) {}
  }

  void _centerMapOnUserCountry() {
    if (_mapController == null ||
        _userLatLng == null ||
        _hasCenteredOnCountry) {
      return;
    }

    _hasCenteredOnCountry = true;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _userLatLng!, zoom: 5.8),
      ),
    );
  }

  void _recenterToUserLocation() {
    if (_mapController == null || _userLatLng == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _userLatLng!, zoom: 13.0),
      ),
    );
  }

  Future<void> _initCustomMarkers() async {
    for (final cat in ApiConfig.allCategories) {
      _categoryMarkers[cat] = await _createCustomPin(cat);
    }
    if (mounted) setState(() {});
  }

  /// Brutalist map pin: flat colored square with thick black border
  Future<BitmapDescriptor> _createCustomPin(String category) async {
    final catColor = AppTheme.getCategoryColor(category);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(40, 52);

    // Hard shadow (offset, no blur)
    final shadowPaint = Paint()..color = Colors.black;
    canvas.drawRect(
      Rect.fromLTWH(3, 3, size.width - 3, size.height * 0.7),
      shadowPaint,
    );
    // Add shadow specifically for the pointer to make it unified
    final shadowPath = Path();
    shadowPath.moveTo((size.width - 3) * 0.35 + 3, size.height * 0.7 + 3);
    shadowPath.lineTo((size.width - 3) * 0.5 + 3, size.height);
    shadowPath.lineTo((size.width - 3) * 0.65 + 3, size.height * 0.7 + 3);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Pin body (sharp square with pointer)
    final path = Path();
    // Square body
    path.addRect(Rect.fromLTWH(0, 0, size.width - 3, size.height * 0.7));
    // Triangle pointer
    path.moveTo((size.width - 3) * 0.35, size.height * 0.7);
    path.lineTo((size.width - 3) * 0.5, size.height - 3);
    path.lineTo((size.width - 3) * 0.65, size.height * 0.7);
    path.close();

    // Fill
    canvas.drawPath(path, Paint()..color = catColor);
    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = 2.5,
    );

    // Letter (centered in square body)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final letterColor =
        catColor.computeLuminance() > 0.5 ? AppTheme.black : AppTheme.white;
    textPainter.text = TextSpan(
      text: category.isNotEmpty ? category[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: letterColor,
        fontFamily: 'monospace',
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        ((size.width - 3) - textPainter.width) / 2,
        (size.height * 0.7 - textPainter.height) / 2,
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

    final padding = markers.length == 1 ? 20.0 : 40.0;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Consumer<MapViewModel>(
          builder: (context, vm, _) {
            final markers = _buildMarkers(vm);

            if ((markers.length != _lastMarkersCount ||
                    vm.selectedCategory != _lastCategoryFilter) &&
                markers.isNotEmpty &&
                _userLatLng == null) {
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
                    zoom: 2,
                  ),
                  markers: markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _centerMapOnUserCountry();
                    if (!_hasCenteredOnCountry && markers.isNotEmpty) {
                      _fitMarkers(markers);
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // ── Top overlay ──
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      // Info pill (brutalist)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: AppTheme.brutalBox(
                          context,
                          color: AppTheme.bg(context),
                          shadow: true,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.red,
                                border: Border.all(
                                  color: AppTheme.fg(context),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.pin_drop,
                                color: AppTheme.bg(context),
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userCountry?.isNotEmpty == true
                                    ? '${vm.reelsWithLocations.length} PLACES PINNED IN ${_userCountry!.toUpperCase()}'
                                    : '${vm.reelsWithLocations.length} PLACES PINNED',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.fg(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Category chips
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ApiConfig.broadCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final cat = ApiConfig.broadCategories[i];
                            return CategoryBadge(
                              category: cat,
                              isSelected: vm.selectedCategory == cat,
                              customHeight: 32,
                              customFontSize: 9,
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
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppTheme.yellow,
                        shadow: true,
                      ),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.fg(context),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),

                // ── Error ──
                if (!vm.isLoading && vm.error != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppTheme.bg(context),
                        shadow: true,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.destructive,
                              border: Border.all(
                                color: AppTheme.fg(context),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.cloud_off,
                              color: AppTheme.bg(context),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'COULD NOT LOAD MAP DATA',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.fg(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            vm.error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => vm.loadMapReels(forceRefresh: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: AppTheme.brutalBox(
                                context,
                                color: AppTheme.red,
                                shadow: true,
                              ),
                              child: Text(
                                'RETRY',
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.bg(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Empty ──
                if (!vm.isLoading &&
                    vm.error == null &&
                    vm.reelsWithLocations.isEmpty)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppTheme.bg(context),
                        shadow: true,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.yellow,
                              border: Border.all(
                                color: AppTheme.fg(context),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.location_off,
                              size: 22,
                              color: AppTheme.fg(context),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'NO LOCATIONS YET',
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.fg(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reels with place mentions will\nshow up here on the map.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Selected reel sheet ──
                if (vm.selectedReel != null)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: _buildPinSheet(context, vm.selectedReel!),
                  ),

                // ── Map buttons ──
                Positioned(
                  right: 16,
                  bottom: vm.selectedReel != null ? 280 : 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (markers.isNotEmpty)
                        _mapButton(
                          icon: Icons.fit_screen,
                          onTap: () => _fitMarkers(markers),
                        ),
                      if (_userLatLng != null) ...[
                        const SizedBox(height: 8),
                        _mapButton(
                          icon: Icons.my_location,
                          onTap: _recenterToUserLocation,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: AppTheme.brutalBox(
          context,
          color: AppTheme.bg(context),
          shadow: true,
        ),
        child: Icon(icon, size: 20, color: AppTheme.fg(context)),
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
                _categoryMarkers[reel.subCategory] ??
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.brutalBox(
        context,
        color: AppTheme.bg(context),
        shadow: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: catColor,
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                    child: Text(
                      reel.category.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: catColor.computeLuminance() > 0.5
                            ? AppTheme.black
                            : AppTheme.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.read<MapViewModel>().selectReel(null),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fg(context), width: 2),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppTheme.fg(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            reel.title.toUpperCase(),
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (reel.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reel.summary,
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Location
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen,
                  border: Border.all(color: AppTheme.fg(context), width: 1.5),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 10,
                  color: AppTheme.fg(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reel.locations.map((l) => l.name).join(', ').toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Buttons
          Row(
            children: [
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: AppTheme.brutalBox(
                      context,
                      color: AppTheme.bg(context),
                      shadow: true,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'DETAILS',
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.fg(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: AppTheme.brutalBox(
                      context,
                      color: AppTheme.red,
                      shadow: true,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions,
                          size: 16,
                          color: AppTheme.bg(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GO',
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.bg(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
    );
  }
}
