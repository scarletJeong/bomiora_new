/// 아이디 찾기 API 응답에서 이메일(아이디) 목록을 추출합니다.
List<String> parseFindIdAccountEmails(Map<String, dynamic> result) {
  final raw = result['accounts'];
  final list = raw is List<dynamic> ? raw : const <dynamic>[];
  return list
      .map((item) => item is Map ? (item['email'] ?? '').toString() : '')
      .where((email) => email.isNotEmpty)
      .toList();
}
