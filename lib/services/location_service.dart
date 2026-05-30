import 'package:geolocator/geolocator.dart';

enum LocationPermissionState { enabled, disabled, serviceDisabled }

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<LocationPermissionState> getPermissionState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionState.serviceDisabled;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return LocationPermissionState.enabled;
    }

    return LocationPermissionState.disabled;
  }

  Future<Position?> getCurrentOrLastKnownLocation({
    bool requestPermissionIfNeeded = true,
  }) async {
    final hasPermission = requestPermissionIfNeeded
        ? await requestPermission()
        : await _hasLocationPermission();

    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<void> warmUpLocation() async {
    await getCurrentOrLastKnownLocation(requestPermissionIfNeeded: true);
  }

  Future<bool> _hasLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
