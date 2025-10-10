class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '', // int를 String으로 변환
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone']?.toString(), // 안전한 null 처리
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone
    );
  }
}
