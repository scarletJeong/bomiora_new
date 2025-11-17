class UserModel {
  final String id;
  final String email;
  final String name;
  final String? nickname; // 닉네임 추가
  final String? phone;
  final String? password; // 비밀번호 저장

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.nickname,
    this.phone,
    this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    
    final id = json['id']?.toString() ?? json['mb_id']?.toString() ?? '';
    final email = json['email'] ?? json['mb_email'] ?? '';
    final name = json['name'] ?? json['mb_name'] ?? '';
    final nickname = json['nickname']?.toString() ?? json['mb_nick']?.toString();
    //  mb_hp 필드 추가 (API에서 mb_hp로 응답함)
    final phone = json['phone']?.toString() ?? 
                  json['mb_phone']?.toString() ?? 
                  json['mb_hp']?.toString();
    final password = json['password']?.toString();
    
    return UserModel(
      id: id,
      email: email,
      name: name,
      nickname: nickname,
      phone: phone,
      password: password,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      if (nickname != null) 'nickname': nickname,
      'phone': phone,
      if (password != null) 'password': password,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? nickname,
    String? phone,
    String? password,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      password: password ?? this.password,
    );
  }
}
