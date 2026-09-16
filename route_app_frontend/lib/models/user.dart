class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String status;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    required this.status,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    role: json['role'],
    phone: json['phone'],
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
  );

  bool get isAdmin => role == 'admin' || role == 'supervisor';
  bool get isDriver => role == 'driver';
}
