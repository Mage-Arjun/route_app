class Customer {
  final int id;
  final String code;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? serviceNotes;
  final String status;
  final DateTime? createdAt;
  Customer({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.contactPerson,
    this.phone,
    this.email,
    this.serviceNotes,
    required this.status,
    this.createdAt,
  });
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] as int,
    code: j['code'] as String? ?? '',
    name: j['name'] as String? ?? '',
    address: j['address'] as String?,
    latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
    contactPerson: j['contact_name'] as String?,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    serviceNotes: j['service_notes'] as String?,
    status: j['status'] as String? ?? 'active',
    createdAt: j['created_at'] == null
        ? null
        : DateTime.parse(j['created_at'] as String),
  );
  String get customerType => 'customer';
  String get typeLabel => status[0].toUpperCase() + status.substring(1);
  int get serviceDurationMins => 10;
  String? get notes => serviceNotes;
}
