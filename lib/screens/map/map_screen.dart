import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reelpin/data_models/map/map_place_search_response.dart';
import 'package:reelpin/data_models/map/map_response.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/router.dart';
import 'package:reelpin/services/location/location_service.dart';
import 'package:reelpin/constants/app_layout.dart';
import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/constants/app_theme.dart';
import 'package:reelpin/view_models/map_view_model.dart';
import 'package:reelpin/components/reels/category_badge.dart';
import 'package:reelpin/screens/reel_detail/reel_detail_screen.dart';
part 'partials/map_place_search_sheet.dart';

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
    final catColor = AppColors.getCategoryColor(category);

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
        ? AppColors.black
        : AppColors.white;
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
      backgroundColor: AppColors.bg(context),
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
                                color: AppColors.bg(context),
                                shadow: true,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: layout.inset(20),
                                    height: layout.inset(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.red,
                                      border: Border.all(
                                        color: AppColors.fg(context),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.pin_drop,
                                      color: AppColors.bg(context),
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
                                        color: AppColors.fg(context),
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
                // Restored pins stay visible while the refresh runs.
                if (vm.isLoading && vm.mapItems.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.yellow,
                        shadow: true,
                      ),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.fg(context),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),

                // ── Error ──
                if (!vm.isLoading && vm.error != null && vm.mapItems.isEmpty)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.bg(context),
                        shadow: true,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.destructive,
                              border: Border.all(
                                color: AppColors.fg(context),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.cloud_off,
                              color: AppColors.bg(context),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'COULD NOT LOAD MAP DATA',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.fg(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            vm.error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.textSecondary,
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
                                color: AppColors.red,
                                shadow: true,
                              ),
                              child: Text(
                                'RETRY',
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.bg(context),
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
                        color: AppColors.bg(context),
                        shadow: true,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              border: Border.all(
                                color: AppColors.fg(context),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.location_off,
                              size: 22,
                              color: AppColors.fg(context),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'NO LOCATIONS YET',
                            style: GoogleFonts.spaceMono(
                              color: AppColors.fg(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reels that clearly name places will\nshow up here on the map.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.textSecondary,
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
          color: AppColors.bg(context),
          shadow: true,
        ),
        child: Icon(icon, size: layout.inset(20), color: AppColors.fg(context)),
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
    final catColor = AppColors.getCategoryColor(item.category);
    final supportingTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD0D0D0)
        : AppColors.textSecondary;
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
        color: AppColors.bg(context),
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
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      item.categoryLabel.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: catColor.computeLuminance() > 0.5
                            ? AppColors.black
                            : AppColors.white,
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
                      color: AppColors.destructive,
                      border: Border.all(
                        color: AppColors.fg(context),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 22,
                      color: AppColors.bg(context),
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
                    border: Border.all(color: AppColors.fg(context), width: 2),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 22,
                    color: AppColors.fg(context),
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
              color: AppColors.fg(context),
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
                  color: AppColors.neonGreen,
                  border: Border.all(color: AppColors.fg(context), width: 1.5),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 10,
                  color: AppColors.fg(context),
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
                      Navigator.push(context, reelDetailRoute(item.toReel()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: AppTheme.brutalBox(
                        context,
                        color: AppColors.bg(context),
                        shadow: true,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'DETAILS',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.fg(context),
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
                      color: AppColors.red,
                      shadow: true,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions,
                          size: 16,
                          color: AppColors.bg(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GO',
                          style: GoogleFonts.spaceMono(
                            color: AppColors.bg(context),
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
        backgroundColor: AppColors.bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: BorderSide(
            color: AppColors.fg(context),
            width: AppTheme.borderWidth,
          ),
        ),
        title: Text(
          'REMOVE THIS PIN?',
          style: GoogleFonts.spaceMono(
            color: AppColors.fg(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This only hides the place from your map.',
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.spaceMono(
                color: AppColors.textSec(context),
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
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: success
                      ? AppColors.black
                      : AppColors.destructive,
                ),
              );
            },
            child: Text(
              'REMOVE',
              style: GoogleFonts.spaceMono(
                color: AppColors.destructive,
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
