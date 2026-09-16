class Customer {
  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String customerType;
  final String? customerCode;
  final String? preferredVisitTime;
  final int serviceDurationMins;
  final String? visitDays;
  final String? notes;
  final String status;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.contactPerson,
    this.phone,
    this.email,
    required this.customerType,
    this.customerCode,
    this.preferredVisitTime,
    required this.serviceDurationMins,
    this.visitDays,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    contactPerson: json['contact_person'],
    phone: json['phone'],
    email: json['email'],
    customerType: json['customer_type'],
    customerCode: json['customer_code'],
    preferredVisitTime: json['preferred_visit_time'],
    serviceDurationMins: json['service_duration_mins'],
    visitDays: json['visit_days'],
    notes: json['notes'],
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
  );

  String get typeLabel {
    switch (customerType) {
      case 'retail': return 'Retail';
      case 'wholesale': return 'Wholesale';
      case 'hotel': return 'Hotel';
      case 'pharmacy': return 'Pharmacy';
      default: return customerType;
    }
  }
}
