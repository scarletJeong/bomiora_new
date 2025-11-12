class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? password; // 비밀번호 저장

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    
    final id = json['id']?.toString() ?? '';
    final email = json['email'] ?? json['mb_email'] ?? '';
    final name = json['name'] ?? json['mb_name'] ?? '';
    //  mb_hp 필드 추가 (API에서 mb_hp로 응답함)
    final phone = json['phone']?.toString() ?? 
                  json['mb_phone']?.toString() ?? 
                  json['mb_hp']?.toString();
    final password = json['password']?.toString();
    
    return UserModel(
      id: id,
      email: email,
      name: name,
      phone: phone,
      password: password,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      if (password != null) 'password': password,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? password,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password ?? this.password,
    );
  }
}
