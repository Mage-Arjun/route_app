import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? customer;
  const CustomerFormScreen({super.key, this.customer});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _durationCtrl;
  String _type = 'retail';
  bool _saving = false;
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _contactCtrl = TextEditingController(text: c?.contactPerson ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _latCtrl = TextEditingController(text: c?.latitude.toString() ?? '');
    _lngCtrl = TextEditingController(text: c?.longitude.toString() ?? '');
    _durationCtrl = TextEditingController(text: (c?.serviceDurationMins ?? 15).toString());
    _type = c?.customerType ?? 'retail';
    if (c != null) _pickedLocation = LatLng(c.latitude, c.longitude);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = {
        'code': widget.customer?.code ?? 'CUS-${DateTime.now().millisecondsSinceEpoch}',
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'latitude': double.parse(_latCtrl.text),
        'longitude': double.parse(_lngCtrl.text),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'contact_name': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        'service_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'status': 'active',
      };
      if (widget.customer != null) {
        await api.updateCustomer(widget.customer!.id, data);
      } else {
        await api.createCustomer(data);
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
    final isEdit = widget.customer != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Customer' : 'Add Customer'),
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
            _section('Location', [
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pickedLocation ?? const LatLng(11.2588, 75.7804),
                      initialZoom: 13,
                      onTap: (tapPos, latLng) {
                        setState(() {
                          _pickedLocation = latLng;
                          _latCtrl.text = latLng.latitude.toStringAsFixed(6);
                          _lngCtrl.text = latLng.longitude.toStringAsFixed(6);
                        });
                      },
                    ),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.routeapp'),
                      if (_pickedLocation != null)
                        MarkerLayer(markers: [
                          Marker(point: _pickedLocation!, width: 40, height: 40, child: const Icon(Icons.location_pin, color: AppTheme.error, size: 36)),
                        ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_latCtrl, 'Latitude', keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field(_lngCtrl, 'Longitude', keyboardType: TextInputType.number)),
              ]),
            ]),
            const SizedBox(height: 16),
            _section('Details', [
              _field(_nameCtrl, 'Name *', required: true),
              const SizedBox(height: 12),
              _field(_addressCtrl, 'Address'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'retail', child: Text('Retail')),
                  DropdownMenuItem(value: 'wholesale', child: Text('Wholesale')),
                  DropdownMenuItem(value: 'hotel', child: Text('Hotel')),
                  DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacy')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
            ]),
            const SizedBox(height: 16),
            _section('Contact', [
              _field(_contactCtrl, 'Contact Person'),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Phone', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
            ]),
            const SizedBox(height: 16),
            _section('Other', [
              _field(_durationCtrl, 'Service Duration (mins)', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(_notesCtrl, 'Notes', maxLines: 3),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}
