import 'user.dart';

class Vehicle {
  final int id;
  final String vehicleNumber;
  final String? registration;
  final String vehicleType;
  final double capacityKg;
  final int? assignedDriverId;
  final User? assignedDriver;
  final String status;
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    this.registration,
    required this.vehicleType,
    required this.capacityKg,
    this.assignedDriverId,
    this.assignedDriver,
    required this.status,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'],
    vehicleNumber: json['vehicle_number'],
    registration: json['registration'],
    vehicleType: json['vehicle_type'],
    capacityKg: (json['capacity_kg'] as num).toDouble(),
    assignedDriverId: json['assigned_driver_id'],
    assignedDriver: json['assigned_driver'] != null ? User.fromJson(json['assigned_driver']) : null,
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
  );
}
