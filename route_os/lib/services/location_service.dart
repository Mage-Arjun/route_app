import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

/// Manages GPS location tracking and periodic push to the backend.
class LocationService {
  LocationService(this._api);

  final ApiService _api;
  StreamSubscription<Position>? _positionSub;
  Timer? _pushTimer;
  Position? _lastPosition;
  int? _activeTripId;
  int? _vehicleId;
  bool _running = false;
  String? _lastError;

  bool get isRunning => _running;
  Position? get lastPosition => _lastPosition;
  String? get lastError => _lastError;
  void setVehicleId(int? vehicleId) => _vehicleId = vehicleId;

  /// Android needs a foreground notification for dependable trip tracking
  /// when the driver locks the screen or switches to another app.
  static LocationSettings trackingSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'RouteOS live tracking',
          notificationText:
              'Your trip location is being shared with operations.',
          notificationChannelName: 'RouteOS location tracking',
          setOngoing: true,
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
  }

  /// Request location permissions. Returns false if denied.
  static Future<bool> requestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Start GPS tracking and background push every [pushIntervalSecs] seconds.
  Future<void> start({
    int? tripId,
    int? vehicleId,
    int pushIntervalSecs = 10,
  }) async {
    if (_running) return;
    final granted = await requestPermissions();
    if (!granted) {
      _lastError = 'Location permission or device GPS is disabled';
      return;
    }

    _activeTripId = tripId;
    _vehicleId = vehicleId;
    _running = true;

    final settings = trackingSettings();

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (pos) {
            _lastPosition = pos;
            _lastError = null;
          },
          onError: (error) {
            _lastError = error.toString();
          },
        );

    // Do not wait for the first stream event. A trip should publish a usable
    // location immediately, even if the vehicle is stationary at its depot.
    try {
      _lastPosition = await Geolocator.getLastKnownPosition();
      await _pushLastPosition();
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      await _pushLastPosition();
    } catch (error) {
      _lastError = error.toString();
    }

    // Push to backend on interval
    _pushTimer = Timer.periodic(Duration(seconds: pushIntervalSecs), (_) async {
      await _pushLastPosition();
    });
  }

  Future<void> _pushLastPosition() async {
    final pos = _lastPosition;
    if (pos == null) return;
    try {
      await _api.pushLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        vehicleId: _vehicleId,
        accuracy: pos.accuracy,
        tripId: _activeTripId,
      );
      _lastError = null;
    } catch (error) {
      // Keep the stream alive during a temporary network outage. The next
      // timer tick retries the latest known point.
      _lastError = error.toString();
    }
  }

  /// Stop GPS tracking.
  void stop() {
    _running = false;
    _positionSub?.cancel();
    _pushTimer?.cancel();
    _positionSub = null;
    _pushTimer = null;
    _lastPosition = null;
    _activeTripId = null;
    _vehicleId = null;
  }

  /// One-shot high-accuracy position capture (for stop confirmation).
  static Future<Position?> captureOnce() async {
    final granted = await requestPermissions();
    if (!granted) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
