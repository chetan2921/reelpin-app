import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/map_place_search_response.dart';
import '../models/map_response.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/map_viewmodel.dart';
import '../widgets/category_badge.dart';
import 'reel_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _defaultLatLng = LatLng(20.0, 0.0);
  static const _markerCacheLimit = 96;
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
  bool _isSyncingMarkers = false;
  bool _shouldResyncMarkers = false;
  bool _canShowUserLocation = false;
  MapViewModel? _trackedMapViewModel;

  int _lastMarkersCount = -1;
  String? _lastCategoryFilter;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mapViewModelProvider).loadMapReels(forceRefresh: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final mapVm = ref.read(mapViewModelProvider);
    if (!identical(_trackedMapViewModel, mapVm)) {
      _trackedMapViewModel?.removeListener(_handleMapViewModelChanged);
      _trackedMapViewModel = mapVm;
      _trackedMapViewModel?.addListener(_handleMapViewModelChanged);
      _scheduleVisibleMarkerSync();
    }
  }

  Future<void> _initUserLocation() async {
    final position = await LocationService.instance
        .getCurrentOrLastKnownLocation(requestPermissionIfNeeded: true);

    if (!mounted) return;

    if (position == null) {
      final state = await LocationService.instance.getPermissionState();
      if (!mounted) return;
      setState(() {
        _canShowUserLocation = state == LocationPermissionState.enabled;
      });
      return;
    }

    setState(() {
      _userLatLng = LatLng(position.latitude, position.longitude);
      _canShowUserLocation = true;
    });
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

  Future<void> _refreshMapPins() async {
    await ref.read(mapViewModelProvider).loadMapReels(forceRefresh: true);
  }

  Future<void> _openPlaceSearchSheet() async {
    ref.read(mapViewModelProvider).clearPlaceSearch();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 1,
        child: _MapPlaceSearchSheet(
          onMapItemSelected: _focusMapItem,
          onMapItemPinned: _focusMapItem,
        ),
      ),
    );
    if (mounted) {
      ref.read(mapViewModelProvider).clearPlaceSearch();
    }
  }

  void _focusMapItem(MapItem item) {
    ref.read(mapViewModelProvider).selectMapItem(item);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(item.latitude, item.longitude), zoom: 15),
      ),
    );
  }

  void _handleMapViewModelChanged() {
    _scheduleVisibleMarkerSync();
  }

  void _scheduleVisibleMarkerSync() {
    final mapVm = _trackedMapViewModel;
    if (mapVm == null) return;
    if (_isSyncingMarkers) {
      _shouldResyncMarkers = true;
      return;
    }

    unawaited(_syncVisibleMarkers(mapVm));
  }

  Future<void> _syncVisibleMarkers(MapViewModel mapVm) async {
    if (_isSyncingMarkers) return;

    _isSyncingMarkers = true;
    final requiredColors = <String, String>{};
    for (final item in mapVm.mapItems) {
      requiredColors[item.category] = item.category;
      if (item.subCategory.trim().isNotEmpty) {
        requiredColors[item.subCategory] = item.category;
      }
    }
    if (requiredColors.length > _markerCacheLimit) {
      final limitedEntries = requiredColors.entries
          .take(_markerCacheLimit)
          .toList(growable: false);
      requiredColors
        ..clear()
        ..addEntries(limitedEntries);
    }

    _categoryMarkers.removeWhere(
      (label, _) => !requiredColors.containsKey(label),
    );

    var didAddMarker = false;
    try {
      for (final entry in requiredColors.entries) {
        final label = entry.key;
        if (_categoryMarkers.containsKey(label)) continue;

        _categoryMarkers[label] = await _createCustomPin(entry.value);
        didAddMarker = true;
      }
    } finally {
      _isSyncingMarkers = false;
    }

    if (didAddMarker && mounted) {
      setState(() {});
    }

    if (_shouldResyncMarkers) {
      _shouldResyncMarkers = false;
      _scheduleVisibleMarkerSync();
    }
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
    final vm = ref.watch(mapViewModelProvider);
    final themeVm = ref.watch(themeViewModelProvider);
    final categoryVm = ref.watch(categoryFiltersViewModelProvider);
    final floatingNavClearance =
        MediaQuery.viewPaddingOf(context).bottom + layout.gap(72);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Builder(
          builder: (context) {
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
                  myLocationEnabled: _canShowUserLocation,
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
                      // Info pill and search action
                      Row(
                        children: [
                          Expanded(
                            child: Container(
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
                                      '$totalPins ${totalPins == 1 ? 'PLACE' : 'PLACES'} PINNED',
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
                          ),
                          SizedBox(width: layout.inset(10)),
                          _mapButton(
                            icon: Icons.search,
                            onTap: () {
                              unawaited(_openPlaceSearchSheet());
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: layout.gap(8)),

                      // Category chips
                      SizedBox(
                        height: layout.gap(38),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryVm.categories.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(width: layout.inset(6)),
                          itemBuilder: (_, i) {
                            final cat = categoryVm.categories[i];
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
                if (!vm.isLoading && vm.error == null && markers.isEmpty)
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
                if (vm.selectedMapItem != null)
                  Positioned(
                    bottom: floatingNavClearance,
                    left: 16,
                    right: 16,
                    child: _buildPinSheet(context, vm.selectedMapItem!),
                  ),

                // ── Map buttons ──
                Positioned(
                  right: layout.inset(16),
                  bottom: vm.selectedMapItem != null
                      ? floatingNavClearance + layout.gap(256)
                      : floatingNavClearance,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _mapButton(
                        icon: Icons.refresh,
                        onTap: () {
                          unawaited(_refreshMapPins());
                        },
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

    for (final item in vm.mapItems) {
      markers.add(
        Marker(
          markerId: MarkerId(item.markerId),
          position: LatLng(item.latitude, item.longitude),
          infoWindow: InfoWindow(
            title: item.displayName,
            snippet: item.locationDisplayLabel,
          ),
          icon:
              _categoryMarkers[item.subCategory] ??
              _categoryMarkers[item.category] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          onTap: () => vm.selectMapItem(item),
        ),
      );
    }
    return markers;
  }

  Widget _buildPinSheet(BuildContext context, MapItem item) {
    final catColor = AppTheme.getCategoryColor(item.category);
    final supportingTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD0D0D0)
        : AppTheme.textSecondary;
    final mapsUri = locationMapsSearchUri(
      name: item.locationName,
      displayLabel: item.locationDisplayLabel,
      address: item.locationAddress,
      backendUrl: item.googleMapsUrl,
      latitude: item.latitude,
      longitude: item.longitude,
    );

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
                      item.categoryLabel.toUpperCase(),
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
              if (item.canRemove || item.canHide) ...[
                GestureDetector(
                  onTap: ref.watch(mapViewModelProvider).isRemovingMapPin
                      ? null
                      : () => _confirmRemoveMapItem(context, item),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.destructive,
                      border: Border.all(color: AppTheme.fg(context), width: 2),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 22,
                      color: AppTheme.bg(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => ref.read(mapViewModelProvider).selectMapItem(null),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fg(context), width: 2),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 22,
                    color: AppTheme.fg(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            item.displayName.toUpperCase(),
            style: GoogleFonts.spaceMono(
              color: AppTheme.fg(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (item.displayDetail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.displayDetail,
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
                  item.locationDisplayLabel.toUpperCase(),
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
              if (item.canOpenDetails) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReelDetailScreen(reel: item.toReel()),
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
              ],
              Expanded(
                child: GestureDetector(
                  onTap: mapsUri == null
                      ? null
                      : () async {
                          if (await canLaunchUrl(mapsUri)) {
                            await launchUrl(
                              mapsUri,
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

  void _confirmRemoveMapItem(BuildContext context, MapItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppTheme.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'REMOVE THIS PIN?',
          style: GoogleFonts.spaceMono(
            color: AppTheme.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This only hides the place from your map.',
          style: GoogleFonts.spaceMono(
            color: AppTheme.textSec(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppTheme.textSec(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(mapViewModelProvider)
                  .removeMapItem(item);
              if (!context.mounted) return;

              final vm = ref.read(mapViewModelProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'PIN REMOVED'
                        : vm.mapPinActionError ?? 'COULD NOT REMOVE THIS PIN',
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: success
                      ? AppTheme.black
                      : AppTheme.destructive,
                ),
              );
            },
            child: Text(
              'REMOVE',
              style: GoogleFonts.spaceMono(
                color: AppTheme.destructive,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trackedMapViewModel?.removeListener(_handleMapViewModelChanged);
    super.dispose();
  }
}

class _MapPlaceSearchSheet extends ConsumerStatefulWidget {
  const _MapPlaceSearchSheet({
    required this.onMapItemSelected,
    required this.onMapItemPinned,
  });

  final ValueChanged<MapItem> onMapItemSelected;
  final ValueChanged<MapItem> onMapItemPinned;

  @override
  ConsumerState<_MapPlaceSearchSheet> createState() =>
      _MapPlaceSearchSheetState();
}

class _MapPlaceSearchSheetState extends ConsumerState<_MapPlaceSearchSheet> {
  static const _searchDebounceDelay = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasQuery = false;
  String _lastHandledSearchText = '';
  String _lastSearchedQuery = '';
  String? _savingResultKey;
  _PlaceSearchTab _selectedTab = _PlaceSearchTab.all;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final query = _controller.text.trim();
    final hasQuery = query.isNotEmpty;
    if (_hasQuery != hasQuery) {
      setState(() {
        _hasQuery = hasQuery;
      });
    }

    if (query == _lastHandledSearchText) return;
    _lastHandledSearchText = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDelay, _runSearch);
  }

  void _runSearch({bool force = false}) {
    final query = _controller.text.trim();
    if (query.length < 2) {
      _lastSearchedQuery = '';
      ref.read(mapViewModelProvider).clearPlaceSearch();
      return;
    }

    if (!force && query == _lastSearchedQuery) return;
    _lastSearchedQuery = query;
    unawaited(ref.read(mapViewModelProvider).searchMapPlaces(query));
  }

  Future<void> _handleResultTap(
    MapPlaceSearchResult result,
    String resultKey,
  ) async {
    final existingItem = result.mapItem;
    if (existingItem != null) {
      Navigator.pop(context);
      widget.onMapItemSelected(existingItem);
      return;
    }

    if (!result.canPin) return;
    final googlePlaceId = result.googlePlaceId?.trim();
    if (googlePlaceId == null ||
        googlePlaceId.isEmpty ||
        _savingResultKey != null) {
      return;
    }

    setState(() {
      _savingResultKey = resultKey;
    });

    MapItem? item;
    try {
      item = await ref.read(mapViewModelProvider).pinPlace(result);
    } finally {
      if (mounted) {
        setState(() {
          _savingResultKey = null;
        });
      }
    }

    if (!mounted) return;

    if (item == null) {
      final vm = ref.read(mapViewModelProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vm.mapPinActionError ?? 'COULD NOT SAVE THIS PIN',
            style: GoogleFonts.spaceMono(
              color: AppTheme.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppTheme.destructive,
        ),
      );
      return;
    }

    Navigator.pop(context);
    widget.onMapItemPinned(item);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final vm = ref.watch(mapViewModelProvider);
    final query = _controller.text.trim();
    final showTabs =
        query.length >= 2 &&
        !vm.isSearchingPlaces &&
        vm.placeSearchError == null &&
        vm.placeSearchResults.isNotEmpty;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Material(
        color: AppTheme.bg(context),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.inset(20),
                  layout.gap(16),
                  layout.inset(20),
                  layout.gap(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'SEARCH PLACES',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.fg(context),
                              fontSize: layout.font(
                                20,
                                minFactor: 0.86,
                                maxFactor: 1.05,
                              ),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(width: layout.inset(10)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: layout.inset(40),
                            height: layout.inset(40),
                            decoration: AppTheme.brutalBox(
                              context,
                              color: AppTheme.bg(context),
                              shadow: true,
                            ),
                            child: Icon(
                              Icons.close,
                              size: layout.inset(22),
                              color: AppTheme.fg(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: layout.gap(14)),
                    _buildSearchField(context, vm),
                    if (showTabs) ...[
                      SizedBox(height: layout.gap(12)),
                      _PlaceSearchTabs(
                        selectedTab: _selectedTab,
                        allCount: vm.placeSearchResults.length,
                        savedCount: _savedResults(vm.placeSearchResults).length,
                        onChanged: (tab) {
                          setState(() {
                            _selectedTab = tab;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: _buildResults(context, vm, query)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, MapViewModel vm) {
    final layout = AppLayout.of(context);

    return Container(
      decoration: AppTheme.brutalBox(context, shadow: true),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        cursorColor: AppTheme.fg(context),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _runSearch(force: true),
        style: GoogleFonts.spaceMono(
          color: AppTheme.fg(context),
          fontSize: layout.font(13),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'SEARCH A PLACE OR ADDRESS...',
          hintStyle: GoogleFonts.spaceMono(
            color: AppTheme.textSec(context),
            fontSize: layout.font(12),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.fg(context),
            size: layout.inset(22),
          ),
          suffixIcon: _buildSearchFieldAction(context, vm),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: layout.inset(16),
            vertical: layout.gap(14),
          ),
        ),
      ),
    );
  }

  Widget? _buildSearchFieldAction(BuildContext context, MapViewModel vm) {
    final layout = AppLayout.of(context);
    if (_hasQuery) {
      return IconButton(
        tooltip: 'Clear search',
        onPressed: () {
          _controller.clear();
          ref.read(mapViewModelProvider).clearPlaceSearch();
        },
        icon: Icon(
          Icons.close,
          color: AppTheme.fg(context),
          size: layout.inset(20),
        ),
      );
    }

    if (!vm.isSearchingPlaces) {
      return null;
    }

    return Padding(
      padding: EdgeInsets.all(layout.inset(14)),
      child: SizedBox(
        width: layout.inset(16),
        height: layout.inset(16),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.fg(context),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, MapViewModel vm, String query) {
    final layout = AppLayout.of(context);
    final allResults = vm.placeSearchResults;
    final savedResults = _savedResults(allResults);
    final visibleResults = switch (_selectedTab) {
      _PlaceSearchTab.all => allResults,
      _PlaceSearchTab.saved => savedResults,
    };

    if (vm.isSearchingPlaces) {
      return _PlaceSearchMessage(
        icon: Icons.search,
        title: 'SEARCHING PLACES...',
        accentColor: AppTheme.yellow,
        isLoading: true,
      );
    }

    if (vm.placeSearchError != null) {
      return _PlaceSearchMessage(
        icon: Icons.error_outline,
        title: 'SEARCH FAILED',
        body: vm.placeSearchError!.toUpperCase(),
        accentColor: AppTheme.destructive,
      );
    }

    if (query.length >= 2 && allResults.isEmpty) {
      return _PlaceSearchMessage(
        icon: Icons.search_off,
        title: 'NO PLACES FOUND',
        body: 'TRY A DIFFERENT PLACE NAME OR ADDRESS.',
        accentColor: AppTheme.yellow,
      );
    }

    if (query.length >= 2 &&
        _selectedTab == _PlaceSearchTab.saved &&
        visibleResults.isEmpty) {
      return _PlaceSearchMessage(
        icon: Icons.bookmark_border,
        title: 'NO SAVED PLACES FOUND',
        body: 'SAVED PLACES THAT MATCH THIS SEARCH WILL SHOW HERE.',
        accentColor: AppTheme.yellow,
      );
    }

    if (query.length < 2 || visibleResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        layout.inset(20),
        layout.gap(16),
        layout.inset(20),
        layout.gap(28),
      ),
      itemCount: visibleResults.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _PlaceSearchSummary(
            count: visibleResults.length,
            query: query,
            tab: _selectedTab,
          );
        }

        final resultIndex = index - 1;
        final result = visibleResults[resultIndex];
        final resultKey = _placeResultKey(result, resultIndex);
        return _MapPlaceResultTile(
          result: result,
          isSaving: _savingResultKey == resultKey,
          onTap: () {
            unawaited(_handleResultTap(result, resultKey));
          },
        );
      },
    );
  }

  List<MapPlaceSearchResult> _savedResults(List<MapPlaceSearchResult> results) {
    return results
        .where((result) => result.isExisting || result.mapItem != null)
        .toList(growable: false);
  }

  String _placeResultKey(MapPlaceSearchResult result, int index) {
    return [
      index,
      result.googlePlaceId,
      result.displayTitle,
      result.displayAddress,
    ].whereType<Object>().join('|');
  }
}

enum _PlaceSearchTab { all, saved }

class _PlaceSearchTabs extends StatelessWidget {
  const _PlaceSearchTabs({
    required this.selectedTab,
    required this.allCount,
    required this.savedCount,
    required this.onChanged,
  });

  final _PlaceSearchTab selectedTab;
  final int allCount;
  final int savedCount;
  final ValueChanged<_PlaceSearchTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Container(
      decoration: AppTheme.brutalBox(context, shadow: false),
      child: Row(
        children: [
          Expanded(
            child: _PlaceSearchTabButton(
              label: 'ALL',
              count: allCount,
              isSelected: selectedTab == _PlaceSearchTab.all,
              onTap: () => onChanged(_PlaceSearchTab.all),
            ),
          ),
          Container(
            width: AppTheme.borderWidth,
            height: layout.inset(42),
            color: AppTheme.fg(context),
          ),
          Expanded(
            child: _PlaceSearchTabButton(
              label: 'SAVED',
              count: savedCount,
              isSelected: selectedTab == _PlaceSearchTab.saved,
              onTap: () => onChanged(_PlaceSearchTab.saved),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSearchTabButton extends StatelessWidget {
  const _PlaceSearchTabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: layout.inset(42),
        color: isSelected ? AppTheme.yellow : AppTheme.bg(context),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  color: isSelected ? AppTheme.black : AppTheme.fg(context),
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: layout.inset(6)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.black : AppTheme.yellow,
                  border: Border.all(
                    color: isSelected ? AppTheme.black : AppTheme.fg(context),
                    width: 2,
                  ),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.spaceMono(
                    color: isSelected ? AppTheme.white : AppTheme.black,
                    fontSize: layout.font(9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchMessage extends StatelessWidget {
  const _PlaceSearchMessage({
    required this.icon,
    required this.title,
    required this.accentColor,
    this.body,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color accentColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final iconColor = accentColor.computeLuminance() > 0.5
        ? AppTheme.black
        : AppTheme.white;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: layout.inset(28)),
        child: Container(
          width: double.infinity,
          decoration: AppTheme.brutalCard(context),
          padding: EdgeInsets.all(layout.inset(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: layout.inset(54),
                height: layout.inset(54),
                decoration: AppTheme.brutalBox(
                  context,
                  color: accentColor,
                  shadow: false,
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: layout.inset(24),
                        height: layout.inset(24),
                        child: CircularProgressIndicator(
                          color: iconColor,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: layout.inset(26)),
              ),
              SizedBox(height: layout.gap(16)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  color: AppTheme.fg(context),
                  fontSize: layout.font(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (body != null && body!.isNotEmpty) ...[
                SizedBox(height: layout.gap(8)),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.textSec(context),
                    fontSize: layout.font(11),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchSummary extends StatelessWidget {
  const _PlaceSearchSummary({
    required this.count,
    required this.query,
    required this.tab,
  });

  final int count;
  final String query;
  final _PlaceSearchTab tab;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final label = tab == _PlaceSearchTab.saved ? 'SAVED PLACE' : 'PLACE RESULT';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.yellow,
            border: Border.all(color: AppTheme.fg(context), width: 2),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.spaceMono(
              color: AppTheme.black,
              fontSize: layout.font(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: layout.inset(8)),
        Expanded(
          child: Text(
            '$label${count == 1 ? '' : 'S'} FOR "${query.toUpperCase()}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: AppTheme.textSec(context),
              fontSize: layout.font(11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPlaceResultTile extends StatelessWidget {
  const _MapPlaceResultTile({
    required this.result,
    required this.isSaving,
    required this.onTap,
  });

  final MapPlaceSearchResult result;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final mapItem = result.mapItem;
    final isExisting = result.isExisting;
    final title = _firstNonEmpty([
      result.displayTitle,
      mapItem?.displayName,
      result.placeName,
    ]);
    final subtitle = _firstNonEmpty([
      result.displayAddress,
      mapItem?.locationDisplayLabel,
      mapItem?.displayDetail,
    ]);
    final badgeText = isExisting ? 'SAVED' : null;

    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: Container(
        padding: EdgeInsets.all(layout.inset(14)),
        decoration: AppTheme.brutalBox(
          context,
          color: AppTheme.bg(context),
          shadow: true,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badgeText != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen,
                          border: Border.all(
                            color: AppTheme.fg(context),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.spaceMono(
                            color: AppTheme.black,
                            fontSize: layout.font(8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: layout.gap(8)),
                  ],
                  Text(
                    title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: layout.gap(4)),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceMono(
                        color: AppTheme.textSec(context),
                        fontSize: layout.font(10),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isExisting) ...[
              SizedBox(width: layout.inset(10)),
              SizedBox(
                width: layout.inset(36),
                height: layout.inset(36),
                child: Center(
                  child: isSaving
                      ? SizedBox(
                          width: layout.inset(18),
                          height: layout.inset(18),
                          child: CircularProgressIndicator(
                            color: AppTheme.fg(context),
                            strokeWidth: 2,
                          ),
                        )
                      : Image.asset(
                          'assets/images/pin.png',
                          width: layout.inset(24),
                          height: layout.inset(24),
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
