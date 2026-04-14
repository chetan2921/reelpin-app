import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geofencing/flutter_background_geofencing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recall_region.dart';
import '../models/reel.dart';
import 'location_service.dart';
import 'notification_service.dart';

class GeofenceRecallService {
  GeofenceRecallService({required NotificationService notificationService})
    : _notificationService = notificationService;

  static const _contextsKey = 'geofence_recall_contexts';
  static const _cooldownPrefix = 'geofence_recall_last_trigger_';
  static const _cooldownWindow = Duration(hours: 4);
  static const _maxRegionsIos = 18;
  static const _maxRegionsAndroid = 60;

  final GeofencingService _geofencingService = GeofencingService();
  final NotificationService _notificationService;

  StreamSubscription<GeofenceEvent>? _eventSubscription;
  Map<String, RecallRegion> _contexts = const {};
  bool _initialized = false;
  String? _lastSyncFingerprint;

  Future<void> initialize({bool requestPermissions = true}) async {
    if (_initialized) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final didInitialize = await _geofencingService.initialize();
    if (!didInitialize) return;

    if (requestPermissions) {
      await _geofencingService.requestPermissions();
    }
    await _geofencingService.startService(
      notificationTitle: 'ReelPin Recall Active',
      notificationText: 'Watching your saved places nearby',
      enableFallbackNotifications: true,
      fallbackNotificationTitle: 'ReelPin Recall',
      fallbackNotificationBody: 'You are near {regionName}',
    );

    _contexts = await _loadStoredContexts();

    _eventSubscription = _geofencingService.onGeofenceEvent.listen(
      _handleGeofenceEvent,
      onError: (error) {
        debugPrint('Geofence event error: $error');
      },
    );

    _initialized = true;
  }

  Future<void> syncFromReels(List<Reel> reels) async {
    if (!_initialized) return;

    final fingerprint = reels
        .map((reel) => '${reel.id}:${reel.mappableLocations.length}')
        .join('|');
    if (_lastSyncFingerprint == fingerprint) return;
    _lastSyncFingerprint = fingerprint;

    final contexts = RecallRegion.fromReels(reels);
    final prioritized = await _prioritize(contexts);

    await _geofencingService.removeAllGeofences();
    if (prioritized.isEmpty) {
      _contexts = const {};
      await _persistContexts(const {});
      return;
    }

    final regions = prioritized
        .map(
          (context) => GeofenceRegion(
            id: context.id,
            latitude: context.latitude,
            longitude: context.longitude,
            radius: context.radiusMeters,
            data: context.toJson(),
            loiteringDelayMs: 20000,
          ),
        )
        .toList();

    await _geofencingService.addGeofences(regions);

    _contexts = {for (final context in prioritized) context.id: context};
    await _persistContexts(_contexts);
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    if (_initialized) {
      await _geofencingService.removeAllGeofences();
      await _geofencingService.stopService();
    }
  }

  Future<void> _handleGeofenceEvent(GeofenceEvent event) async {
    if (event.type != GeofenceEventType.enter &&
        event.type != GeofenceEventType.dwell) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastTriggerKey = '$_cooldownPrefix${event.regionId}';
    final lastTriggeredMs = prefs.getInt(lastTriggerKey);
    if (lastTriggeredMs != null) {
      final lastTriggered = DateTime.fromMillisecondsSinceEpoch(
        lastTriggeredMs,
      );
      if (DateTime.now().difference(lastTriggered) < _cooldownWindow) {
        return;
      }
    }

    final region =
        _contexts[event.regionId] ??
        (await _loadStoredContexts())[event.regionId];
    if (region == null) return;

    await _notificationService.showProactiveRecallNotification(region);
    await prefs.setInt(lastTriggerKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<RecallRegion>> _prioritize(List<RecallRegion> regions) async {
    if (regions.isEmpty) return const [];

    final maxRegions = defaultTargetPlatform == TargetPlatform.iOS
        ? _maxRegionsIos
        : _maxRegionsAndroid;
    final currentLocation = await LocationService.instance
        .getCurrentOrLastKnownLocation(requestPermissionIfNeeded: false);

    final weighted =
        regions.map((region) {
          final distanceScore = currentLocation == null
              ? 0.0
              : _distanceSquared(
                  region.latitude,
                  region.longitude,
                  currentLocation.latitude,
                  currentLocation.longitude,
                );
          return _RegionWeight(region: region, distanceSquared: distanceScore);
        }).toList()..sort((a, b) {
          final reelCountCompare = b.region.reelCount.compareTo(
            a.region.reelCount,
          );
          if (reelCountCompare != 0) return reelCountCompare;
          return a.distanceSquared.compareTo(b.distanceSquared);
        });

    return weighted.take(maxRegions).map((item) => item.region).toList();
  }

  double _distanceSquared(double lat1, double lng1, double lat2, double lng2) {
    final latDelta = lat1 - lat2;
    final lngDelta = lng1 - lng2;
    return latDelta * latDelta + lngDelta * lngDelta;
  }

  Future<void> _persistContexts(Map<String, RecallRegion> contexts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = contexts.values.map((context) => context.toJson()).toList();
    await prefs.setString(_contextsKey, jsonEncode(list));
  }

  Future<Map<String, RecallRegion>> _loadStoredContexts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contextsKey);
    if (raw == null || raw.isEmpty) return const {};
    final decoded = RecallRegion.decodeList(raw);
    return {for (final context in decoded) context.id: context};
  }
}

class _RegionWeight {
  const _RegionWeight({required this.region, required this.distanceSquared});

  final RecallRegion region;
  final double distanceSquared;
}
