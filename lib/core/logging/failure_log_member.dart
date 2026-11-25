/// 로그인 회원의 번호와 전화번호. FailureLog가 AuthService를 직접 부르지 않게 둔다.
class FailureLogMember {
  FailureLogMember._();

  static String mbId = '';
  static String phone = '';

  static void sync(String? id, String? phoneNumber) {
    mbId = (id ?? '').trim();
    phone = (phoneNumber ?? '').trim();
  }
}
