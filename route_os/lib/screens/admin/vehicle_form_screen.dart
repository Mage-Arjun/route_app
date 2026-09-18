import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/vehicle.dart';
import '../../models/user.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberCtrl;
  late TextEditingController _regCtrl;
  late TextEditingController _capacityCtrl;
  String _type = 'van';
  int? _driverId;
  bool _saving = false;
  List<User> _drivers = [];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _numberCtrl = TextEditingController(text: v?.vehicleNumber ?? '');
    _regCtrl = TextEditingController(text: v?.registration ?? '');
    _capacityCtrl = TextEditingController(
      text: (v?.capacityKg ?? 500).toInt().toString(),
    );
    _type = v?.vehicleType ?? 'van';
    _driverId = v?.assignedDriverId;
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final api = ref.read(apiServiceProvider);
      final users = await api.getUsers(role: 'driver');
      setState(() => _drivers = users);
    } catch (_) {}
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _regCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = {
        'identifier': _numberCtrl.text.trim(),
        'name': _regCtrl.text.trim().isEmpty
            ? _numberCtrl.text.trim()
            : _regCtrl.text.trim(),
        'type': _type,
      };
      if (widget.vehicle != null) {
        throw UnsupportedError('The backend does not support editing vehicles');
      } else {
        await api.createVehicle(data);
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
    final isEdit = widget.vehicle != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Vehicle' : 'Add Vehicle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_numberCtrl, 'Vehicle Number *', required: true),
            const SizedBox(height: 12),
            _field(_regCtrl, 'Registration'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Vehicle Type'),
              items: const [
                DropdownMenuItem(value: 'van', child: Text('Van')),
                DropdownMenuItem(value: 'truck', child: Text('Truck')),
                DropdownMenuItem(value: 'car', child: Text('Car')),
                DropdownMenuItem(value: 'bike', child: Text('Bike')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            _field(
              _capacityCtrl,
              'Capacity (kg)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _driverId,
              decoration: const InputDecoration(labelText: 'Assigned Driver'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                ..._drivers.map(
                  (d) =>
                      DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                ),
              ],
              onChanged: (v) => setState(() => _driverId = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
