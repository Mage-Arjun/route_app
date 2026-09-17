import 'dart:async';
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

  bool get isRunning => _running;
  Position? get lastPosition => _lastPosition;
  void setVehicleId(int? vehicleId) => _vehicleId = vehicleId;

  /// Request location permissions. Returns false if denied.
  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
  Future<void> start({int? tripId, int? vehicleId, int pushIntervalSecs = 10}) async {
    if (_running) return;
    final granted = await requestPermissions();
    if (!granted) return;

    _activeTripId = tripId;
    _vehicleId = vehicleId;
    _running = true;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,    // meters — only emit if moved ≥ 3m
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
          _lastPosition = pos;
        }, onError: (_) {});

    // Push to backend on interval
    _pushTimer = Timer.periodic(Duration(seconds: pushIntervalSecs), (_) async {
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
      } catch (_) {/* silent — offline tolerance */}
    });
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
