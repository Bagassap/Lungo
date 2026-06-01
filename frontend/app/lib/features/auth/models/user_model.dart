class UserModel {
  final String id;
  final String phone;
  final String name;
  final String role;
  final bool isVerified;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    required this.isVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        isVerified: json['isVerified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        'isVerified': isVerified,
      };

  bool get isNewUser => name.isEmpty || role.isEmpty;
}
