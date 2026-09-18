import 'customer.dart';
import 'user.dart';
import 'vehicle.dart';
import 'route.dart';

class TripStop {
  final int id;
  final int tripId;
  final int routeStopId;
  final int customerId;
  final int sequence;
  final DateTime? arrivalTime;
  final DateTime? departureTime;
  final String status;
  final String? notes;
  final String? driverNotes;
  final Customer? customer;
  // ── Proof of Delivery ──────────────────────────────────
  final String? receiverName;
  final String? signatureData;
  final String? photoUrl;
  final String? failureReason;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final DateTime? completedAt;

  TripStop({
    required this.id,
    required this.tripId,
    required this.routeStopId,
    required this.customerId,
    required this.sequence,
    this.arrivalTime,
    this.departureTime,
    required this.status,
    this.notes,
    this.driverNotes,
    this.customer,
    this.receiverName,
    this.signatureData,
    this.photoUrl,
    this.failureReason,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.completedAt,
  });

  bool get isDone => !['pending'].contains(status);
  bool get isCompleted => status == 'completed';

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
    id: json['id'],
    tripId: json['trip_id'],
    routeStopId: json['route_stop_id'],
    customerId: json['customer_id'],
    sequence: json['sequence'],
    arrivalTime: json['arrival_time'] != null
        ? DateTime.parse(json['arrival_time'])
        : null,
    departureTime: json['departure_time'] != null
        ? DateTime.parse(json['departure_time'])
        : null,
    status: json['status'],
    notes: json['notes'],
    driverNotes: json['driver_notes'],
    customer: json['customer'] != null
        ? Customer.fromJson(json['customer'])
        : null,
    receiverName: json['receiver_name'],
    signatureData: json['signature_data'],
    photoUrl: json['photo_url'],
    failureReason: json['failure_reason'],
    deliveryLatitude: json['delivery_latitude'] != null
        ? (json['delivery_latitude'] as num).toDouble()
        : null,
    deliveryLongitude: json['delivery_longitude'] != null
        ? (json['delivery_longitude'] as num).toDouble()
        : null,
    completedAt: json['completed_at'] != null
        ? DateTime.parse(json['completed_at'])
        : null,
  );
}

class Trip {
  final int id;
  final int routeId;
  final int driverId;
  final int? vehicleId;
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final double totalDistanceKm;
  final int completedStops;
  final int totalStops;
  final String status;
  final DateTime createdAt;
  final Route? route;
  final User? driver;
  final Vehicle? vehicle;
  final List<TripStop> tripStops;

  Trip({
    required this.id,
    required this.routeId,
    required this.driverId,
    this.vehicleId,
    required this.date,
    this.startTime,
    this.endTime,
    required this.totalDistanceKm,
    required this.completedStops,
    required this.totalStops,
    required this.status,
    required this.createdAt,
    this.route,
    this.driver,
    this.vehicle,
    this.tripStops = const [],
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'],
    routeId: json['route_id'],
    driverId: json['driver_id'],
    vehicleId: json['vehicle_id'],
    date: DateTime.parse(json['date']),
    startTime: json['start_time'] != null
        ? DateTime.parse(json['start_time'])
        : null,
    endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
    totalDistanceKm: (json['total_distance_km'] as num).toDouble(),
    completedStops: json['completed_stops'],
    totalStops: json['total_stops'],
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
    route: json['route'] != null ? Route.fromJson(json['route']) : null,
    driver: json['driver'] != null ? User.fromJson(json['driver']) : null,
    vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
    tripStops: json['trip_stops'] != null
        ? (json['trip_stops'] as List).map((s) => TripStop.fromJson(s)).toList()
        : [],
  );

  double get completionRate => totalStops > 0 ? completedStops / totalStops : 0;
}
