import '../../../core/utils/node_value_parser.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? nickname; // 닉네임 추가
  final String? phone;
  final String? password; // 비밀번호 저장
  final String? profileImage; // 프로필 이미지 경로/URL

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.nickname,
    this.phone,
    this.password,
    this.profileImage,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);

    final id =
        NodeValueParser.asString(normalized['id']) ??
        NodeValueParser.asString(normalized['mb_id']) ??
        NodeValueParser.asString(normalized['mbId']) ??
        NodeValueParser.asString(normalized['mb_no']) ??
        '';
    final email =
        NodeValueParser.asString(normalized['email']) ??
        NodeValueParser.asString(normalized['mb_email']) ??
        '';
    final name =
        NodeValueParser.asString(normalized['name']) ??
        NodeValueParser.asString(normalized['mb_name']) ??
        '';
    final nickname =
        NodeValueParser.asString(normalized['nickname']) ??
        NodeValueParser.asString(normalized['mb_nick']);
    //  mb_hp 필드 추가 (API에서 mb_hp로 응답함)
    final phone =
        NodeValueParser.asString(normalized['phone']) ??
        NodeValueParser.asString(normalized['mb_phone']) ??
        NodeValueParser.asString(normalized['mb_hp']);
    final password = NodeValueParser.asString(normalized['password']);
    final profileImage =
        NodeValueParser.asString(normalized['profileImage']) ??
        NodeValueParser.asString(normalized['profile_img']);
    
    return UserModel(
      id: id,
      email: email,
      name: name,
      nickname: nickname,
      phone: phone,
      password: password,
      profileImage: profileImage,
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
      if (profileImage != null) 'profileImage': profileImage,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? nickname,
    String? phone,
    String? password,
    String? profileImage,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}
