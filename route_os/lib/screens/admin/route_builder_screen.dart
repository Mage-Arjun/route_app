import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// The result returned to the route form after the operator finishes planning.
class RouteDraft {
  final List<List<double>> geometry;

  const RouteDraft(this.geometry);

  LatLng? get start =>
      geometry.isEmpty ? null : LatLng(geometry.first[1], geometry.first[0]);

  LatLng? get end =>
      geometry.isEmpty ? null : LatLng(geometry.last[1], geometry.last[0]);
}

/// A small route planner with two practical workflows:
/// - Draw: tap the map to create waypoints.
/// - Record: walk/drive the route and let GPS add points.
///
/// It deliberately returns a draft instead of saving directly. The parent
/// route form still owns the final Save button, so users cannot accidentally
/// create half-filled routes.
class RouteBuilderScreen extends ConsumerStatefulWidget {
  final List<LatLng> initialPoints;

  const RouteBuilderScreen({super.key, this.initialPoints = const []});

  @override
  ConsumerState<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends ConsumerState<RouteBuilderScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  late List<LatLng> _points;
  List<Map<String, dynamic>> _results = [];
  StreamSubscription<Position>? _gpsSubscription;
  bool _recording = false;
  bool _searching = false;
  bool _routing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _points = [...widget.initialPoints];
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _addPoint(LatLng point) {
    setState(() {
      _points.add(point);
      _message = '${_points.length} waypoint${_points.length == 1 ? '' : 's'}';
    });
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 3) return;
    setState(() {
      _searching = true;
      _results = [];
    });
    try {
      final results = await ref.read(apiServiceProvider).searchPlaces(query);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _message = 'Location search failed: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(Map<String, dynamic> result) {
    final point = LatLng(
      (result['latitude'] as num).toDouble(),
      (result['longitude'] as num).toDouble(),
    );
    _addPoint(point);
    _mapController.move(point, 14);
    setState(() => _results = []);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _gpsSubscription?.cancel();
      setState(() => _recording = false);
      return;
    }
    final permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      setState(
        () => _message = 'Location permission is needed to record a route.',
      );
      return;
    }
    setState(() {
      _recording = true;
      _message = 'Recording GPS route…';
    });
    _gpsSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen((position) {
          final point = LatLng(position.latitude, position.longitude);
          if (!mounted) return;
          _addPoint(point);
          _mapController.move(point, 16);
        });
  }

  Future<void> _followRoads() async {
    if (_points.length < 2 || _recording) return;
    setState(() {
      _routing = true;
      _message = 'Finding a drivable path…';
    });
    try {
      final waypoints = _points
          .map((point) => [point.longitude, point.latitude])
          .toList();
      final geometry = await ref
          .read(apiServiceProvider)
          .routeGeometry(waypoints);
      if (!mounted) return;
      setState(() {
        _points = geometry.map((point) => LatLng(point[1], point[0])).toList();
        _message = 'Road-following path ready';
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not follow roads: $error');
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _finish() {
    if (_points.length < 2) {
      setState(() => _message = 'Add at least a start and an end point.');
      return;
    }
    Navigator.pop(
      context,
      RouteDraft(
        _points.map((point) => [point.longitude, point.latitude]).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan route'),
        actions: [
          IconButton(
            onPressed: _undo,
            tooltip: 'Undo last point',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: _finish,
            tooltip: 'Use this route',
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.touch_app),
                  label: Text('Draw on map'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.gps_fixed),
                  label: Text('Record GPS'),
                ),
              ],
              selected: {_recording},
              onSelectionChanged: (_) => _toggleRecording(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search any city, address, or landmark worldwide',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
              ),
            ),
          ),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, index) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(_results[index]['name'] as String),
                    onTap: () => _selectResult(_results[index]),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _points.isEmpty
                        ? const LatLng(20, 0)
                        : _points.first,
                    initialZoom: _points.isEmpty ? 2 : 13,
                    onTap: _recording ? null : (_, point) => _addPoint(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.routeapp',
                    ),
                    if (_points.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _points,
                            color: AppTheme.primary,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (var index = 0; index < _points.length; index++)
                          Marker(
                            point: _points[index],
                            width: 34,
                            height: 34,
                            child: CircleAvatar(
                              backgroundColor: index == 0
                                  ? AppTheme.success
                                  : index == _points.length - 1
                                  ? AppTheme.error
                                  : AppTheme.primary,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_message != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(_message!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_points.length} points • Tap the map to add a waypoint',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _routing ? null : _followRoads,
                    icon: _routing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alt_route),
                    label: const Text('Follow roads'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _finish,
                    icon: const Icon(Icons.check),
                    label: const Text('Use route'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
