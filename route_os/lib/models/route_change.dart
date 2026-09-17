class RouteChange {
  final int id;
  final int routeId;
  final int? customerId;
  final int? recommendedSequence;
  final double additionalDistanceKm;
  final double additionalTimeMins;
  final String status;
  final int? requestedById;
  final int? approvedById;
  final String? requestedByName;
  final String? approvedByName;
  final String? customerName;
  final String? routeName;
  final DateTime createdAt;

  RouteChange({
    required this.id,
    required this.routeId,
    required this.customerId,
    required this.recommendedSequence,
    required this.additionalDistanceKm,
    required this.additionalTimeMins,
    required this.status,
    this.requestedById,
    this.approvedById,
    this.requestedByName,
    this.approvedByName,
    this.customerName,
    this.routeName,
    required this.createdAt,
  });

  factory RouteChange.fromJson(Map<String, dynamic> json) {
    return RouteChange(
      id: json['id'],
      routeId: json['route_id'],
      customerId: json['customer_id'],
      recommendedSequence: json['recommended_sequence'],
      additionalDistanceKm: (json['additional_distance_km'] ?? 0).toDouble(),
      additionalTimeMins: (json['additional_time_mins'] ?? 0).toDouble(),
      status: json['status'],
      requestedById: json['requested_by_id'],
      approvedById: json['approved_by_id'],
      requestedByName: json['requested_by']?['name'],
      approvedByName: json['approved_by']?['name'],
      customerName: json['customer']?['name'],
      routeName: json['route']?['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
