import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../models/vehicle.dart';
import '../../models/route.dart' as models;

class RouteFormScreen extends ConsumerStatefulWidget {
  final models.Route? route;
  const RouteFormScreen({super.key, this.route});

  @override
  ConsumerState<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends ConsumerState<RouteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  late TextEditingController _nameCtrl;
  late TextEditingController _areaCtrl;
  int? _driverId;
  int? _vehicleId;
  bool _saving = false;
  List<User> _drivers = [];
  List<Vehicle> _vehicles = [];
  LatLng? _depotLocation;

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _areaCtrl = TextEditingController(text: r?.area ?? '');
    _driverId = r?.assignedDriverId;
    _vehicleId = r?.assignedVehicleId;
    if (r?.startLat != null && r?.startLng != null) {
      _depotLocation = LatLng(r!.startLat!, r.startLng!);
    } else {
      _depotLocation = const LatLng(11.2588, 75.7804);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiServiceProvider);
      final users = await api.getUsers(role: 'driver');
      final vehicles = await api.getVehicles();
      setState(() { _drivers = users; _vehicles = vehicles; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = {
        'code': widget.route?.code ?? 'ROUTE-${DateTime.now().millisecondsSinceEpoch}',
        'name': _nameCtrl.text.trim(),
        'description': _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
        'assigned_driver_id': _driverId,
        'assigned_vehicle_id': _vehicleId,
      };
      if (widget.route != null) {
        await api.updateRoute(widget.route!.id, data);
      } else {
        await api.createRoute(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.route != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Route' : 'Add Route'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_nameCtrl, 'Route Name *', required: true),
            const SizedBox(height: 12),
            _field(_areaCtrl, 'Area'),
            const SizedBox(height: 16),
            Text('Depot Location', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _depotLocation!,
                    initialZoom: 13,
                    onTap: (tapPos, latLng) {
                      setState(() => _depotLocation = latLng);
                    },
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.routeapp'),
                    if (_depotLocation != null)
                      MarkerLayer(markers: [
                        Marker(point: _depotLocation!, width: 40, height: 40, child: const Icon(Icons.warehouse, color: AppTheme.primary, size: 36)),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _driverId,
              decoration: const InputDecoration(labelText: 'Assigned Driver'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                ..._drivers.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name))),
              ],
              onChanged: (v) => setState(() => _driverId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _vehicleId,
              decoration: const InputDecoration(labelText: 'Assigned Vehicle'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                ..._vehicles.map((v) => DropdownMenuItem<int?>(value: v.id, child: Text('${v.vehicleNumber} (${v.vehicleType})'))),
              ],
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}
