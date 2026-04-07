/// 8~16자, 영문·숫자·특수문자(비영숫자 1자 이상) 포함 — 회원가입·비밀번호 재설정 공통 규칙
final RegExp appPasswordPattern = RegExp(
  r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).{8,16}$',
);

bool isValidAppPassword(String value) => appPasswordPattern.hasMatch(value);
