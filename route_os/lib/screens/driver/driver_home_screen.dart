import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/route.dart' as models;
import '../../models/trip.dart';
import '../../services/location_service.dart';
import 'trip_screen.dart';
import 'driver_profile_screen.dart';
import '../shared/app_drawer.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  List<models.Route> _routes = [];
  List<Trip> _activeTrips = [];
  bool _loading = true;
  bool _hasLocationPermission = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final granted = await LocationService.requestPermissions();
    if (mounted) {
      setState(() => _hasLocationPermission = granted);
    }
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final routes = await api.getRoutes();
      final trips = await api.getTrips(status: 'active');
      if (mounted) setState(() { _routes = routes; _activeTrips = trips; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTrip(int tripId) async {
    try {
      // Load the detail before changing screens so a stale list item cannot
      // open a blank trip screen after the trip has been closed elsewhere.
      await ref.read(apiServiceProvider).getTrip(tripId);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => TripScreen(tripId: tripId)));
      if (mounted) _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to open trip: $e'), backgroundColor: AppTheme.error,
      ));
    }
  }

  Future<void> _showCreateRouteDialog() async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController(text: 'Kozhikode');
    final startAddrCtrl = TextEditingController(text: 'Depot / Beach Road');
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_road_rounded, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Start First Trip / New Route',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Create a route and activate GPS to draw the path and add stops as you drive.',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Route Name (e.g. Kozhikode Distribution 1)',
                  labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Area / Zone',
                  labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: startAddrCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Start Landmark / Depot',
                  labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: const Color(0xFF0A0D14),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setModalState(() => isSubmitting = true);
                    try {
                      final api = ref.read(apiServiceProvider);
                      // 1. Create the Route
                      final route = await api.createRoute({
                        'name': name,
                        'area': areaCtrl.text.trim(),
                        'start_address': startAddrCtrl.text.trim(),
                        'start_lat': 11.2588,
                        'start_lng': 75.7804,
                      });
                      // 2. Start Trip immediately
                      final trip = await api.startTrip(route.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)));
                        _loadData();
                      }
                    } catch (e) {
                      setModalState(() => isSubmitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  icon: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0D14)))
                      : const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: Text(
                    isSubmitting ? 'Starting Trip...' : 'Create Route & Start First Trip',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOperatorOnly() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Routes are created and assigned by an operator.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      drawer: const AppDrawer(isDriver: true),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), tooltip: 'Open menu', onPressed: () => Scaffold.of(context).openDrawer())),
        title: Text('My Routes', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color(0xFF0A0D14),
        onPressed: _showOperatorOnly,
        icon: const Icon(Icons.add_road_rounded),
        label: Text('New Route', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── GPS Permission Banner ────────────────────────
                  if (!_hasLocationPermission) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off_rounded, color: AppTheme.error, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GPS Permission Needed',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Allow location access so your route drawing and stops can be recorded in real-time.',
                                  style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _checkLocationPermission,
                            child: Text('Enable', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Header & Greeting ────────────────────────────
                  Text(
                    'Hello, ${auth.user?.name ?? 'Driver'}',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record your delivery stops or continue an assigned route.',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // ── Create Route Call-to-action Card ─────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF131F2E), Color(0xFF162A2B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.alt_route_rounded, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First Trip / New Route',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Drive with GPS active to auto-draw the route and add stops on the road.',
                                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: const Color(0xFF0A0D14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showOperatorOnly,
                          child: Text('+ Start', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_activeTrips.isNotEmpty) ...[
                    Text(
                      'Active Trip',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    ..._activeTrips.map((trip) => _activeTripCard(trip)),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'My Routes',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  if (_routes.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.route_outlined, size: 40, color: AppTheme.textMuted),
                              const SizedBox(height: 8),
                              Text('No routes assigned yet', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                ),
                                onPressed: _showOperatorOnly,
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Route'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._routes.map((route) => _routeCard(route)),
                  const SizedBox(height: 80), // padding for FAB
                ],
              ),
            ),
    );
  }


  Widget _activeTripCard(Trip trip) {
    return Card(
      color: AppTheme.primary.withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTrip(trip.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.route?.name ?? 'Trip #${trip.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: trip.completionRate,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  trip.completionRate > 0.7 ? AppTheme.success : AppTheme.warning,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${trip.completedStops} of ${trip.totalStops} stops completed',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: () => _openTrip(trip.id),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Continue Trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeCard(models.Route route) {
    final stops = route.activeStops;
    final hasMap = route.startLat != null && route.startLng != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Start Trip?'),
              content: Text('Start a trip on ${route.name} with ${stops.length} stops?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Start'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            try {
              final api = ref.read(apiServiceProvider);
              final trip = await api.startTrip(route.id);
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TripScreen(tripId: trip.id)));
                _loadData();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                );
              }
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasMap)
              SizedBox(
                height: 120,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(route.startLat!, route.startLng!),
                      initialZoom: 12,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.routeapp',
                      ),
                      MarkerLayer(
                        markers: [
                          for (final stop in stops)
                            if (stop.customer != null)
                              Marker(
                                point: LatLng(stop.customer!.latitude, stop.customer!.longitude),
                                width: 20,
                                height: 20,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: AppTheme.primary,
                                  child: Text('${stop.sequence}', style: const TextStyle(color: Colors.white, fontSize: 8)),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.store, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${stops.length} stops', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDays(route.workingDays),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(String? workingDays) {
    if (workingDays == null) return 'Not set';
    try {
      final days = List<String>.from(Uri.decodeComponent(workingDays).replaceAll('[', '').replaceAll(']', '').split(',').map((d) => d.trim().replaceAll('"', '')));
      return days.join(', ');
    } catch (e) {
      return workingDays;
    }
  }
}
