import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _style = 'https://demotiles.maplibre.org/style.json';
  MapLibreMapController? _map;
  List<Vehicle> _vehicles = const [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vehicles = await ref.read(apiServiceProvider).getVehicles();
      if (mounted)
        setState(() {
          _vehicles = vehicles;
          _loading = false;
          _error = null;
        });
      await _drawVehicles();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Unable to load vehicle locations';
        });
    }
  }

  Future<void> _drawVehicles() async {
    final map = _map;
    if (map == null) return;
    await map.clearSymbols();
    final points = _vehicles
        .where(
          (v) =>
              v.latitude != null &&
              v.longitude != null &&
              (v.latitude != 0 || v.longitude != 0),
        )
        .map(
          (v) => SymbolOptions(
            geometry: LatLng(v.latitude!, v.longitude!),
            textField: v.identifier,
            textColor: '#0E6B51',
            textSize: 12,
            iconImage: 'marker-15',
          ),
        )
        .toList();
    if (points.isNotEmpty) await map.addSymbols(points);
  }

  void _onMapCreated(MapLibreMapController controller) {
    _map = controller;
    _drawVehicles();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Operations Map'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: Stack(
      children: [
        MapLibreMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(11.2588, 75.7804),
            zoom: 10,
          ),
          styleString: _style,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _drawVehicles,
          compassEnabled: true,
          // Admin tracking uses driver vehicle positions from the backend;
          // do not start a second native location layer for the admin device.
          myLocationEnabled: false,
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('${_vehicles.length} vehicles'),
            ),
          ),
        ),
      ],
    ),
  );
}
