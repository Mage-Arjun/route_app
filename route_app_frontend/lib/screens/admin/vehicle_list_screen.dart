import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/vehicle.dart';
import 'vehicle_form_screen.dart';

class VehicleListScreen extends ConsumerStatefulWidget {
  const VehicleListScreen({super.key});

  @override
  ConsumerState<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends ConsumerState<VehicleListScreen> {
  List<Vehicle> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final vehicles = await api.getVehicles();
      setState(() { _vehicles = vehicles; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles & Drivers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleFormScreen()));
          if (result == true) _loadVehicles();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVehicles,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _vehicles.length,
                itemBuilder: (context, index) => _vehicleCard(_vehicles[index]),
              ),
            ),
    );
  }

  Widget _vehicleCard(Vehicle vehicle) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleFormScreen(vehicle: vehicle)));
          if (result == true) _loadVehicles();
        },
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_vehicleIcon(vehicle.vehicleType), color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vehicle.vehicleNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vehicle.vehicleType.toUpperCase(),
                    style: TextStyle(color: AppTheme.info, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.scale, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('${vehicle.capacityKg.toInt()} kg capacity',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            if (vehicle.assignedDriver != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Icon(Icons.person, size: 14, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vehicle.assignedDriver!.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${vehicle.assignedDriver!.role})',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No driver assigned',
                style: TextStyle(color: AppTheme.warning, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'van': return Icons.local_shipping;
      case 'truck': return Icons.fire_truck;
      case 'car': return Icons.directions_car;
      case 'bike': return Icons.two_wheeler;
      default: return Icons.directions_car;
    }
  }
}
