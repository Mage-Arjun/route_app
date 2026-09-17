import 'user.dart';
class Vehicle {
  final int id; final String identifier; final String name; final String type; final String status;
  final double? latitude; final double? longitude; final int? assignedDriverId; final User? assignedDriver;
  final DateTime? createdAt;
  Vehicle({required this.id, required this.identifier, required this.name, required this.type, required this.status,
    this.latitude, this.longitude, this.assignedDriverId, this.assignedDriver, this.createdAt});
  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as int, identifier: j['identifier'] as String? ?? '', name: j['name'] as String? ?? '',
    type: j['type'] as String? ?? 'van', status: j['status'] as String? ?? 'available',
    latitude: (j['latitude'] as num?)?.toDouble(), longitude: (j['longitude'] as num?)?.toDouble(),
    createdAt: j['created_at'] == null ? null : DateTime.parse(j['created_at'] as String));
  String get vehicleNumber => identifier; String get vehicleType => type;
  String? get registration => null; double get capacityKg => 0;
}
