// Android/iOS용 stub 파일
// 웹에서는 실제 dart:html이 사용됨

/// 웹 환경이 아닌 경우 사용되는 stub 클래스
class Window {
  Location get location => Location();
}

class Location {
  String get href => '';
  set hash(String value) {}
}

/// 웹 환경이 아닌 경우 사용되는 stub 네임스페이스
final window = Window();

