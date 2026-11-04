/// 8~16자, 영문·숫자·특수문자(공백이 아닌 비영숫자 1자 이상) 포함.
/// 공백이 있으면 거절한다. 회원가입·비밀번호 재설정·비밀번호 변경이 같이 쓴다.
final RegExp appPasswordPattern = RegExp(
  r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d\s])[^\s]{8,16}$',
);

bool isValidAppPassword(String value) => appPasswordPattern.hasMatch(value);
