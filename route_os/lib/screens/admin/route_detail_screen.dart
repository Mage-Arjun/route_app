import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/route.dart' as models;
import 'route_form_screen.dart';
import 'route_analytics_screen.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  final int routeId;
  const RouteDetailScreen({super.key, required this.routeId});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  models.Route? _route;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    try {
      final api = ref.read(apiServiceProvider);
      final route = await api.getRoute(widget.routeId);
      setState(() { _route = route; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Route')), body: const Center(child: CircularProgressIndicator()));
    }
    final route = _route;
    if (route == null) {
      return Scaffold(appBar: AppBar(title: const Text('Route')), body: const Center(child: Text('Route not found')));
    }

    final stops = route.activeStops;
    final hasMapData = route.startLat != null && route.startLng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => RouteAnalyticsScreen(routeId: route.id),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(
                builder: (_) => RouteFormScreen(route: route),
              ));
              if (result == true) _loadRoute();
            },
          ),
          if (route.assignedDriver != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  route.assignedDriver!.name,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasMapData) _buildMap(route, stops),
          Expanded(
            child: stops.isEmpty
                ? const Center(child: Text('No stops on this route'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final customer = stop.customer;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            '${stop.sequence}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(customer?.name ?? 'Stop ${stop.sequence}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(customer?.address ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stop.serviceDurationMins} min',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            if (stop.plannedArrivalTime != null)
                              Text(
                                stop.plannedArrivalTime!,
                                style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(models.Route route, List<models.RouteStop> stops) {
    final points = <LatLng>[];
    
    if (route.startLat != null && route.startLng != null) {
      points.add(LatLng(route.startLat!, route.startLng!));
    }
    for (final stop in stops) {
      if (stop.customer != null) {
        points.add(LatLng(stop.customer!.latitude, stop.customer!.longitude));
      }
    }
    if (route.endLat != null && route.endLng != null) {
      points.add(LatLng(route.endLat!, route.endLng!));
    }

    if (points.isEmpty) return const SizedBox();

    final center = points.reduce((a, b) => LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    ));

    return SizedBox(
      height: 250,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.routeapp',
          ),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: AppTheme.primary.withOpacity(0.7),
                  strokeWidth: 3,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (route.startLat != null && route.startLng != null)
                Marker(
                  point: LatLng(route.startLat!, route.startLng!),
                  width: 30,
                  height: 30,
                  child: const Icon(Icons.warehouse, color: AppTheme.primary, size: 24),
                ),
              for (int i = 0; i < stops.length; i++)
                if (stops[i].customer != null)
                  Marker(
                    point: LatLng(stops[i].customer!.latitude, stops[i].customer!.longitude),
                    width: 30,
                    height: 30,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
