import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/reel.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../widgets/category_badge.dart';
import 'reel_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _defaultLatLng = LatLng(20.0, 0.0);
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1a2024"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#d5dde6"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a2024"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#46515a"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f0f4f8"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#232b30"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#20272b"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#242d33"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#214133"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#303840"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#161b1f"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#44515d"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1b232a"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2a333b"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#163246"}]}
]
''';

  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _categoryMarkers = {};
  LatLng? _userLatLng;
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
    _centerMapOnUserCountry();
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
    final letterColor = catColor.computeLuminance() > 0.5
        ? AppTheme.black
        : AppTheme.white;
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
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Consumer2<MapViewModel, ThemeViewModel>(
          builder: (context, vm, themeVm, _) {
            final markers = _buildMarkers(vm);
            final totalPins = vm.totalPinnedLocations;

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
                  style: themeVm.isDarkMode ? _darkMapStyle : null,
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
                  top: layout.gap(12),
                  left: layout.inset(16),
                  right: layout.inset(16),
                  child: Column(
                    children: [
                      // Info pill (brutalist)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.inset(14),
                          vertical: layout.gap(10),
                        ),
                        decoration: AppTheme.brutalBox(
                          context,
                          color: AppTheme.bg(context),
                          shadow: true,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: layout.inset(20),
                              height: layout.inset(20),
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
                                size: layout.inset(12),
                              ),
                            ),
                            SizedBox(width: layout.inset(8)),
                            Expanded(
                              child: Text(
                                '$totalPins PLACES PINNED',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.fg(context),
                                  fontSize: layout.font(11),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: layout.gap(8)),

                      // Category chips
                      SizedBox(
                        height: layout.gap(38),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ApiConfig.broadCategories.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(width: layout.inset(6)),
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
                            'Reels that clearly name places will\nshow up here on the map.',
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
                    child: _buildPinSheet(
                      context,
                      vm.selectedReel!,
                      vm.selectedLocation,
                    ),
                  ),

                // ── Map buttons ──
                Positioned(
                  right: layout.inset(16),
                  bottom: vm.selectedReel != null
                      ? layout.gap(280)
                      : layout.gap(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (markers.isNotEmpty)
                        _mapButton(
                          icon: Icons.fit_screen,
                          onTap: () => _fitMarkers(markers),
                        ),
                      if (_userLatLng != null) ...[
                        SizedBox(height: layout.gap(8)),
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
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: layout.inset(44),
        height: layout.inset(44),
        decoration: AppTheme.brutalBox(
          context,
          color: AppTheme.bg(context),
          shadow: true,
        ),
        child: Icon(icon, size: layout.inset(20), color: AppTheme.fg(context)),
      ),
    );
  }

  Set<Marker> _buildMarkers(MapViewModel vm) {
    final markers = <Marker>{};
    for (final reel in vm.reelsWithLocations) {
      final locations = reel.mappableLocations;
      for (var index = 0; index < locations.length; index++) {
        final loc = locations[index];
        markers.add(
          Marker(
            markerId: MarkerId(
              '${reel.id}_${index}_${loc.name}_${loc.latitude}_${loc.longitude}',
            ),
            position: LatLng(loc.latitude!, loc.longitude!),
            infoWindow: InfoWindow(title: reel.title, snippet: loc.name),
            icon:
                _categoryMarkers[reel.subCategory] ??
                _categoryMarkers[reel.category] ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            onTap: () => vm.selectReel(reel, location: loc),
          ),
        );
      }
    }
    return markers;
  }

  Widget _buildPinSheet(
    BuildContext context,
    Reel reel,
    Location? selectedLocation,
  ) {
    final catColor = AppTheme.getCategoryColor(reel.category);
    final supportingTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD0D0D0)
        : AppTheme.textSecondary;
    final fallbackLocation = reel.mappableLocations.isNotEmpty
        ? reel.mappableLocations.first
        : null;
    final activeLocation = selectedLocation ?? fallbackLocation;

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
                color: supportingTextColor,
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
                  (activeLocation != null
                          ? [
                              activeLocation.name,
                              activeLocation.address ?? '',
                            ].where((part) => part.isNotEmpty).join(' • ')
                          : reel.locations.map((l) => l.name).join(', '))
                      .toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: supportingTextColor,
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
                  onTap: activeLocation == null
                      ? null
                      : () async {
                          final loc = activeLocation;
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
