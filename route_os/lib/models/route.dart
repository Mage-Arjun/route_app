import 'customer.dart';
import 'user.dart';
import 'vehicle.dart';

class RouteStop {
  final int id;
  final int routeId;
  final int customerId;
  final int sequence;
  final String? plannedArrivalTime;
  final int serviceDurationMins;
  final String? notes;
  final String status;
  final Customer? customer;

  RouteStop({
    required this.id,
    required this.routeId,
    required this.customerId,
    required this.sequence,
    this.plannedArrivalTime,
    required this.serviceDurationMins,
    this.notes,
    required this.status,
    this.customer,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    id: json['id'],
    routeId: json['route_id'],
    customerId: json['customer_id'],
    sequence: json['sequence'],
    plannedArrivalTime: json['planned_arrival_time'],
    serviceDurationMins: json['service_duration_mins'],
    notes: json['notes'],
    status: json['status'],
    customer: json['customer'] != null ? Customer.fromJson(json['customer']) : null,
  );
}

class Route {
  final int id;
  final String code;
  final String name;
  final String? area;
  final String? workingDays;
  final double? startLat;
  final double? startLng;
  final String? startAddress;
  final double? endLat;
  final double? endLng;
  final String? endAddress;
  final int? assignedDriverId;
  final int? assignedVehicleId;
  final int version;
  final String status;
  final DateTime createdAt;
  final User? assignedDriver;
  final Vehicle? assignedVehicle;
  final List<RouteStop> stops;

  Route({
    required this.id,
    this.code = '',
    required this.name,
    this.area,
    this.workingDays,
    this.startLat,
    this.startLng,
    this.startAddress,
    this.endLat,
    this.endLng,
    this.endAddress,
    this.assignedDriverId,
    this.assignedVehicleId,
    required this.version,
    required this.status,
    required this.createdAt,
    this.assignedDriver,
    this.assignedVehicle,
    this.stops = const [],
  });

  factory Route.fromJson(Map<String, dynamic> json) => Route(
    id: json['id'],
    code: json['code'] ?? '',
    name: json['name'],
    area: json['area'] ?? json['description'],
    workingDays: json['working_days'],
    startLat: json['start_lat']?.toDouble(),
    startLng: json['start_lng']?.toDouble(),
    startAddress: json['start_address'],
    endLat: json['end_lat']?.toDouble(),
    endLng: json['end_lng']?.toDouble(),
    endAddress: json['end_address'],
    assignedDriverId: json['assigned_driver_id'],
    assignedVehicleId: json['assigned_vehicle_id'],
    version: json['version'],
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
    assignedDriver: json['assigned_driver'] != null ? User.fromJson(json['assigned_driver']) : null,
    assignedVehicle: json['assigned_vehicle'] != null ? Vehicle.fromJson(json['assigned_vehicle']) : null,
    stops: json['stops'] != null
        ? (json['stops'] as List).map((s) => RouteStop.fromJson(s)).toList()
        : [],
  );

  List<RouteStop> get activeStops =>
      stops.where((s) => s.status == 'active').toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
}
