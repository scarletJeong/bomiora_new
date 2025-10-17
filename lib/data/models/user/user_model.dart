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
    print('🏗️ [UserModel.fromJson] 입력 데이터: $json');
    
    final id = json['id']?.toString() ?? '';
    final email = json['email'] ?? json['mb_email'] ?? '';
    final name = json['name'] ?? json['mb_name'] ?? '';
    final phone = json['phone']?.toString() ?? json['mb_phone']?.toString();
    
    print('🏗️ [UserModel.fromJson] 파싱 결과:');
    print('   - id: $id');
    print('   - email: $email');
    print('   - name: $name');
    print('   - phone: $phone');
    
    return UserModel(
      id: id,
      email: email,
      name: name,
      phone: phone,
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
