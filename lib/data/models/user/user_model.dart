import '../../../core/utils/node_value_parser.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? nickname; // 닉네임 추가
  /// 닉네임 마지막 변경일 (`mb_nick_date`, YYYY-MM-DD 등)
  final String? nicknameChangedAt;
  final String? phone;
  final String? password; // 비밀번호 저장
  final String? profileImage; // 프로필 이미지 경로/URL
  /// 회원 생년월일(가능한 포맷: YYYYMMDD / yyyy-MM-dd 등)
  final String? birthDate;
  /// 회원 성별(가능한 값: M/F/1/2/남/여 등)
  final String? sex;
  /// 회원 레벨 (`mb_level`, 5=인플루언서)
  final int mbLevel;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.nickname,
    this.nicknameChangedAt,
    this.phone,
    this.password,
    this.profileImage,
    this.birthDate,
    this.sex,
    this.mbLevel = 0,
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
    final nicknameChangedAt =
        NodeValueParser.asString(normalized['nicknameChangedAt']) ??
        NodeValueParser.asString(normalized['mb_nick_date']) ??
        NodeValueParser.asString(normalized['mbNickDate']);
    //  mb_hp 필드 추가 (API에서 mb_hp로 응답함)
    final phone =
        NodeValueParser.asString(normalized['phone']) ??
        NodeValueParser.asString(normalized['mb_phone']) ??
        NodeValueParser.asString(normalized['mb_hp']);
    final password = NodeValueParser.asString(normalized['password']);
    final profileImage =
        NodeValueParser.asString(normalized['profileImage']) ??
        NodeValueParser.asString(normalized['profile_img']);
    final birthDate =
        NodeValueParser.asString(normalized['birthDate']) ??
        NodeValueParser.asString(normalized['mbBirth']) ??
        NodeValueParser.asString(normalized['mb_birth']);
    final sex =
        NodeValueParser.asString(normalized['sex']) ??
        NodeValueParser.asString(normalized['mbSex']) ??
        NodeValueParser.asString(normalized['mb_sex']);
    final mbLevel =
        NodeValueParser.asInt(normalized['mbLevel']) ??
        NodeValueParser.asInt(normalized['mb_level']) ??
        0;
    
    return UserModel(
      id: id,
      email: email,
      name: name,
      nickname: nickname,
      nicknameChangedAt: nicknameChangedAt,
      phone: phone,
      password: password,
      profileImage: profileImage,
      birthDate: birthDate,
      sex: sex,
      mbLevel: mbLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      if (nickname != null) 'nickname': nickname,
      if (nicknameChangedAt != null) 'nicknameChangedAt': nicknameChangedAt,
      'phone': phone,
      if (password != null) 'password': password,
      if (profileImage != null) 'profileImage': profileImage,
      if (birthDate != null) 'birthDate': birthDate,
      if (sex != null) 'sex': sex,
      'mbLevel': mbLevel,
      'mb_level': mbLevel,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? nickname,
    String? nicknameChangedAt,
    String? phone,
    String? password,
    String? profileImage,
    String? birthDate,
    String? sex,
    int? mbLevel,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      nicknameChangedAt: nicknameChangedAt ?? this.nicknameChangedAt,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      mbLevel: mbLevel ?? this.mbLevel,
    );
  }

  bool get isInfluencer => mbLevel == 5;
}
