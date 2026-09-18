import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip.dart';
import '../../services/location_service.dart';

class TripScreen extends ConsumerStatefulWidget {
  final int tripId;
  const TripScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen>
    with SingleTickerProviderStateMixin {
  Trip? _trip;
  bool _loading = true;
  bool _updatingStop = false;
  late TabController _tabController;

  LocationService? _locationService;
  StreamSubscription<Position>? _positionSub;
  final List<LatLng> _livePathPoints = [];
  LatLng? _currentPosition;
  double? _currentAccuracy;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrip();
  }

  Future<void> _startGpsTracking(int? vehicleId) async {
    final granted = await LocationService.requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enable device Location and allow RouteOS location permission.',
            ),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    final api = ref.read(apiServiceProvider);
    _locationService = LocationService(api);
    _locationService!.start(
      tripId: widget.tripId,
      vehicleId: vehicleId,
      pushIntervalSecs: 8,
    );

    final settings = LocationService.trackingSettings();

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
          if (mounted) {
            setState(() {
              final pt = LatLng(pos.latitude, pos.longitude);
              _currentPosition = pt;
              _currentAccuracy = pos.accuracy;
              _livePathPoints.add(pt);
            });
          }
        }, onError: (_) {});

    try {
      final initPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(initPos.latitude, initPos.longitude);
          _currentAccuracy = initPos.accuracy;
          _livePathPoints.add(_currentPosition!);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS could not get a fresh fix: $error'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _locationService?.stop();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    try {
      final api = ref.read(apiServiceProvider);
      final trip = await api.getTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _loading = false;
        });
        await _startGpsTracking(trip.vehicleId);
        if (mounted && _locationService?.lastError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS warning: ${_locationService!.lastError}'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Navigate to stop via Google Maps / Apple Maps
  Future<void> _navigateTo(double lat, double lng, String name) async {
    final encoded = Uri.encodeComponent(name);
    final url = Uri.parse(
      'https://maps.google.com/maps?daddr=$lat,$lng&q=$encoded',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app')),
        );
      }
    }
  }

  /// Show the full PoD bottom sheet for a stop
  Future<void> _showPodModal(TripStop stop) async {
    if (_updatingStop) return;
    _updatingStop = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PodBottomSheet(
          stop: stop,
          tripId: widget.tripId,
          onCompleted: () {
            Navigator.pop(ctx);
            _loadTrip();
          },
        ),
      );
    } finally {
      if (mounted) _updatingStop = false;
    }
  }

  Future<void> _completeTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Trip?'),
        content: const Text('Mark this trip as completed and return to depot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.completeTrip(widget.tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Trip completed! Great work!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _addStopAtCurrentLocation() async {
    if (_trip == null) return;

    // Grab high-accuracy GPS fix
    Position? pos = await LocationService.captureOnce();
    pos ??= _currentPosition != null
        ? Position(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            timestamp: DateTime.now(),
            accuracy: _currentAccuracy ?? 8.0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          )
        : null;

    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not acquire GPS fix. Please ensure location is enabled.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    final lat = pos.latitude;
    final lng = pos.longitude;
    final accuracy = pos.accuracy;

    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController(
      text: 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}',
    );
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
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
                      const Icon(
                        Icons.add_location_alt_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Record Stop at Current GPS',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Live GPS Coordinates indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}  (±${accuracy.toStringAsFixed(1)}m)',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'GPS ACCURATE',
                        style: TextStyle(
                          color: Color(0xFF0A0D14),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Stop / Customer Name (e.g. Kozhikode Store)',
                  labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Address / Landmark',
                  labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Delivery Notes (Optional)',
                  labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setModalState(() => isSaving = true);
                          try {
                            final api = ref.read(apiServiceProvider);
                            await api.recordStop(widget.tripId, {
                              'name': name,
                              'latitude': lat,
                              'longitude': lng,
                              'address': addressCtrl.text.trim(),
                              'notes': notesCtrl.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '📍 Stop "$name" added! Route sequence updated.',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: AppTheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              await _loadTrip();
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add stop: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0A0D14),
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    isSaving
                        ? 'Inserting & Re-sequencing...'
                        : 'Save & Auto-Insert Stop',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Trip...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final stops = [...trip.tripStops]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final completedCount = stops.where((s) => s.isDone).length;
    final totalCount = stops.length;
    final nextStop = stops.where((s) => !s.isDone).firstOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: trip.status == 'active'
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              foregroundColor: const Color(0xFF0A0D14),
              onPressed: _addStopAtCurrentLocation,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: Text(
                'Record Stop Here',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      appBar: AppBar(
        title: Text(trip.route?.name ?? 'Trip #${trip.id}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Stops'),
            Tab(icon: Icon(Icons.map, size: 18), text: 'Map'),
          ],
        ),
        actions: [
          if (trip.status == 'active')
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Complete Trip',
              onPressed: _completeTrip,
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'cancel') _showCancelDialog();
            },
            itemBuilder: (_) => [
              if (trip.status == 'active')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel Trip'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressHeader(stops, completedCount, totalCount, nextStop),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStopsList(stops, nextStop),
                _buildFullMap(trip, stops),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(
    List<TripStop> stops,
    int completed,
    int total,
    TripStop? nextStop,
  ) {
    final rate = total > 0 ? completed / total : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed of $total stops done',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (nextStop != null)
                      Text(
                        'Next: ${nextStop.customer?.name ?? 'Stop ${nextStop.sequence}'}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: rate >= 1.0 ? AppTheme.success : AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 10,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                rate >= 1.0
                    ? AppTheme.success
                    : rate > 0.5
                    ? AppTheme.warning
                    : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList(List<TripStop> stops, TripStop? nextStop) {
    return RefreshIndicator(
      onRefresh: _loadTrip,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: stops.length,
        itemBuilder: (context, index) {
          final stop = stops[index];
          final isCurrent = nextStop?.id == stop.id;
          return _StopCard(
            stop: stop,
            isCurrent: isCurrent,
            onTap: stop.isDone ? null : () => _showPodModal(stop),
            onNavigate: stop.customer != null
                ? () => _navigateTo(
                    stop.customer!.latitude,
                    stop.customer!.longitude,
                    stop.customer!.name,
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildFullMap(Trip trip, List<TripStop> stops) {
    final mapPoints = <LatLng>[];
    if (trip.route?.startLat != null) {
      mapPoints.add(LatLng(trip.route!.startLat!, trip.route!.startLng!));
    }
    for (final s in stops) {
      if (s.customer != null) {
        mapPoints.add(LatLng(s.customer!.latitude, s.customer!.longitude));
      }
    }

    final LatLng center =
        _currentPosition ??
        (mapPoints.isNotEmpty
            ? (mapPoints.length == 1
                  ? mapPoints.first
                  : mapPoints.reduce(
                      (a, b) => LatLng(
                        (a.latitude + b.latitude) / 2,
                        (a.longitude + b.longitude) / 2,
                      ),
                    ))
            : const LatLng(11.2588, 75.7804)); // Kozhikode default

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.routeapp.production',
            ),
            // Progressive live path drawn as vehicle moves
            PolylineLayer(
              polylines: [
                if (_livePathPoints.length > 1)
                  Polyline(
                    points: _livePathPoints,
                    color: AppTheme.neonCyan,
                    strokeWidth: 4.5,
                  ),
                if (mapPoints.length > 1)
                  Polyline(
                    points: mapPoints,
                    color: AppTheme.primary.withValues(alpha: 0.6),
                    strokeWidth: 2.5,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Live Vehicle Marker
                if (_currentPosition != null)
                  Marker(
                    point: _currentPosition!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.neonCyan, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonCyan.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.navigation_rounded,
                          color: AppTheme.neonCyan,
                          size: 22,
                        ),
                      ),
                    ),
                  ),

                // Depot marker
                if (trip.route?.startLat != null)
                  Marker(
                    point: LatLng(trip.route!.startLat!, trip.route!.startLng!),
                    width: 36,
                    height: 36,
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey,
                      child: Icon(
                        Icons.warehouse,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Stop markers
                for (int i = 0; i < stops.length; i++)
                  if (stops[i].customer != null)
                    Marker(
                      point: LatLng(
                        stops[i].customer!.latitude,
                        stops[i].customer!.longitude,
                      ),
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: stops[i].isDone
                            ? null
                            : () => _showPodModal(stops[i]),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: _statusColor(stops[i].status),
                          child: Text(
                            '${stops[i].sequence}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),

        // Floating GPS accuracy badge on top-left of map
        if (_currentPosition != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.neonCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'GPS Active (±${(_currentAccuracy ?? 5.0).toStringAsFixed(1)}m)',
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'skipped':
        return AppTheme.warning;
      case 'refused':
        return AppTheme.error;
      case 'closed':
        return Colors.grey;
      case 'partial':
        return Colors.orange;
      case 'rescheduled':
        return Colors.purple;
      default:
        return AppTheme.info;
    }
  }

  void _showCancelDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text('Are you sure you want to cancel this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.cancelTrip(widget.tripId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Stop Card Widget
// ────────────────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  final TripStop stop;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;

  const _StopCard({
    required this.stop,
    required this.isCurrent,
    this.onTap,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final customer = stop.customer;
    final color = _statusColor(stop.status);

    return Card(
      elevation: isCurrent ? 3 : 1,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(color: AppTheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Sequence badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: stop.isDone ? color.withOpacity(0.15) : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: stop.isDone
                      ? Icon(_statusIcon(stop.status), size: 16, color: color)
                      : Text(
                          '${stop.sequence}',
                          style: TextStyle(
                            color: stop.isDone ? color : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? 'Stop ${stop.sequence}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: stop.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (customer?.address != null)
                      Text(
                        customer!.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (stop.receiverName != null)
                      Text(
                        '✓ Received by: ${stop.receiverName}',
                        style: TextStyle(color: AppTheme.success, fontSize: 11),
                      ),
                    if (stop.failureReason != null)
                      Text(
                        '⚠ ${stop.failureReason}',
                        style: TextStyle(color: AppTheme.error, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!stop.isDone && onNavigate != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(
                        Icons.navigation,
                        color: AppTheme.info,
                        size: 20,
                      ),
                      tooltip: 'Navigate',
                      onPressed: onNavigate,
                    ),
                  if (!stop.isDone && onTap != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onTap,
                      child: const Text(
                        'Deliver',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        stop.status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'skipped':
        return AppTheme.warning;
      case 'refused':
        return AppTheme.error;
      case 'closed':
        return Colors.grey;
      case 'partial':
        return Colors.orange;
      case 'rescheduled':
        return Colors.purple;
      default:
        return AppTheme.info;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check;
      case 'skipped':
        return Icons.skip_next;
      case 'refused':
        return Icons.block;
      case 'closed':
        return Icons.lock;
      case 'partial':
        return Icons.pie_chart;
      case 'rescheduled':
        return Icons.event_repeat;
      default:
        return Icons.radio_button_unchecked;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Proof-of-Delivery Bottom Sheet
// ────────────────────────────────────────────────────────────────────────────

class _PodBottomSheet extends ConsumerStatefulWidget {
  final TripStop stop;
  final int tripId;
  final VoidCallback onCompleted;

  const _PodBottomSheet({
    required this.stop,
    required this.tripId,
    required this.onCompleted,
  });

  @override
  ConsumerState<_PodBottomSheet> createState() => _PodBottomSheetState();
}

class _PodBottomSheetState extends ConsumerState<_PodBottomSheet> {
  final _receiverController = TextEditingController();
  final _notesController = TextEditingController();
  final _signatureKey = GlobalKey<SfSignaturePadState>();
  String _selectedStatus = 'completed';
  String? _failureReason;
  File? _photoFile;
  String? _signatureBase64;
  bool _submitting = false;

  static const _statusOptions = [
    ('completed', 'Delivered', Icons.check_circle, AppTheme.success),
    ('partial', 'Partial', Icons.pie_chart, Colors.orange),
    ('skipped', 'Skipped', Icons.skip_next, AppTheme.warning),
    ('refused', 'Refused', Icons.block, AppTheme.error),
    ('closed', 'Shop Closed', Icons.lock, Colors.grey),
    ('rescheduled', 'Reschedule', Icons.event_repeat, Colors.purple),
  ];

  static const _failureReasons = [
    'Shop closed',
    'Owner not present',
    'Order refused - price dispute',
    'Order refused - wrong items',
    'No space / storage full',
    'Payment issue',
    'Safety concern',
    'Other',
  ];

  @override
  void dispose() {
    _receiverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (image != null) {
      setState(() => _photoFile = File(image.path));
    }
  }

  Future<void> _captureSignature() async {
    try {
      final imageData = await _signatureKey.currentState!.toImage(
        pixelRatio: 2.0,
      );
      final byteData = await imageData.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        setState(() => _signatureBase64 = base64Encode(bytes));
      }
    } catch (e) {
      // signature pad might be empty
    }
  }

  bool get _requiresRecipient =>
      _selectedStatus == 'completed' || _selectedStatus == 'partial';
  bool get _requiresReason =>
      _selectedStatus != 'completed' && _selectedStatus != 'partial';

  Future<void> _submit() async {
    if (_requiresRecipient && _receiverController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the receiver\'s name'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    if (_requiresReason && _failureReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final api = ref.read(apiServiceProvider);

      // Capture signature if signed
      await _captureSignature();

      final receiver = _receiverController.text.trim();
      if (_selectedStatus == 'completed' || _selectedStatus == 'partial') {
        await api.uploadPod(
          widget.tripId,
          widget.stop.id,
          receiverName: receiver,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          signatureData: _signatureBase64,
          imageFile: _photoFile,
        );
      } else {
        await api.updateTripStop(widget.tripId, widget.stop.id, {
          'action': _selectedStatus == 'skipped' ? 'skip' : 'fail',
          'failure_reason': _failureReason,
          'driver_notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        });
      }

      if (mounted) widget.onCompleted();
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.stop.customer;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer?.name ?? 'Stop ${widget.stop.sequence}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        if (customer?.address != null)
                          Text(
                            customer!.address!,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stop #${widget.stop.sequence}',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  // ─ Status Selection ─
                  _sectionTitle('Delivery Status'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusOptions.map((opt) {
                      final (value, label, icon, color) = opt;
                      final selected = _selectedStatus == value;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedStatus = value;
                          _failureReason = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.15)
                                : Theme.of(
                                    ctx,
                                  ).colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: selected
                                  ? color
                                  : Theme.of(ctx).colorScheme.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: selected
                                    ? color
                                    : Theme.of(
                                        ctx,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? color
                                      : AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ─ Failure Reason (conditional) ─
                  if (_requiresReason) ...[
                    _sectionTitle('Reason *'),
                    DropdownButtonFormField<String>(
                      value: _failureReason,
                      hint: const Text('Select reason'),
                      decoration: const InputDecoration(),
                      items: _failureReasons
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _failureReason = v),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─ Receiver Name ─
                  if (_requiresRecipient) ...[
                    _sectionTitle(
                      _selectedStatus == 'completed'
                          ? 'Receiver Name *'
                          : 'Partial Receiver Name',
                    ),
                    TextFormField(
                      controller: _receiverController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Name of person who received goods',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─ Delivery Photo ─
                  _sectionTitle('Delivery Photo'),
                  if (_photoFile != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _photoFile!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _photoFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            ctx,
                          ).colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 32,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to take photo',
                              style: TextStyle(
                                color: Theme.of(
                                  ctx,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ─ E-Signature ─
                  if (_requiresRecipient) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Customer Signature'),
                        TextButton.icon(
                          onPressed: () => _signatureKey.currentState?.clear(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SfSignaturePad(
                          key: _signatureKey,
                          minimumStrokeWidth: 2.0,
                          maximumStrokeWidth: 4.0,
                          strokeColor: Theme.of(ctx).colorScheme.onSurface,
                          backgroundColor: Theme.of(
                            ctx,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─ Notes ─
                  _sectionTitle('Driver Notes (optional)'),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Any notes for the admin...',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─ Submit button ─
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _submitting ? 'Submitting...' : 'Submit Delivery',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _statusOptions
                            .firstWhere(
                              (o) => o.$1 == _selectedStatus,
                              orElse: () => _statusOptions.first,
                            )
                            .$4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
