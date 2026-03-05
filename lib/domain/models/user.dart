/// User model with role and tenant context.
enum UserRole { occupant, manager, admin }

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String tenantId;
  final Map<String, dynamic> claims;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.tenantId,
    this.claims = const {},
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.occupant,
      ),
      tenantId: json['tenantId'] as String,
      claims: (json['claims'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'tenantId': tenantId,
        'claims': claims,
      };

  User copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? tenantId,
    Map<String, dynamic>? claims,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        role: role ?? this.role,
        tenantId: tenantId ?? this.tenantId,
        claims: claims ?? this.claims,
      );
}
