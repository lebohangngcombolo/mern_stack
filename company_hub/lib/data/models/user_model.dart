// lib/data/models/user_model.dart
class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final bool isActive;
  final bool mfaEnabled;
  final bool onboardingCompleted;
  final bool firstLogin;
  final DateTime? lastLogin;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.mfaEnabled,
    required this.onboardingCompleted,
    required this.firstLogin,
    this.lastLogin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      role: json['role'],
      isActive: json['is_active'],
      mfaEnabled: json['mfa_enabled'],
      onboardingCompleted: json['onboarding_completed'],
      firstLogin: json['first_login'],
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'is_active': isActive,
      'mfa_enabled': mfaEnabled,
      'onboarding_completed': onboardingCompleted,
      'first_login': firstLogin,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  // -------------------- copyWith --------------------
  User copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    bool? isActive,
    bool? mfaEnabled,
    bool? onboardingCompleted,
    bool? firstLogin,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      firstLogin: firstLogin ?? this.firstLogin,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
