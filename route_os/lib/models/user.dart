class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String status;
  final DateTime createdAt;

  User({required this.id, required this.name, required this.email, required this.role,
    this.phone, required this.status, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: (json['name'] as String?) ?? (json['email'] as String? ?? 'User'),
    email: json['email'] as String? ?? '', role: json['role'] as String? ?? 'operator',
    phone: json['phone'] as String?, status: json['status'] as String? ?? 'active',
    createdAt: json['created_at'] == null ? DateTime.now() : DateTime.parse(json['created_at'] as String),
  );

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
}
