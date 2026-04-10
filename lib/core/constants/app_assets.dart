/// `pubspec.yaml`의 `assets:`에 `assets/img/`만 등록된 이미지 경로.
/// 새 이미지도 `assets/img/` 아래에 두고 여기에 상수로 추가하면 됩니다.
abstract final class AppAssets {
  AppAssets._();

  static const String _img = 'assets/img/';

  /// 포인트 화면 등에서 사용하는 포인트 아이콘 (SVG)
  static const String pointIcon = '${_img}point_icon.svg';

  /// 쿠폰 화면 등에서 사용하는 쿠폰 아이콘 (SVG)
  static const String couponIcon = '${_img}coupon_icon.svg';

  /// 마이페이지 상단 통계 카드 아이콘/테두리 (SVG)
  static const String deliveryMain = '${_img}deliveryMain.svg';
  static const String couponMain = '${_img}couponMain.svg';
  static const String pointMain = '${_img}pointMain.svg';
  static const String mypageMenuBorder = '${_img}mypage_menu_border.svg';

  /// 홈 리뷰 카드 오버레이 (PNG) — 프로젝트 `assets/img/review_card_overlay.png`
  static const String reviewCardOverlay = '${_img}review_card_overlay.png';

  /// 앱 로고 (PNG)
  static const String bomioraLogo = '${_img}bomiora-logo.png';
  static const String bomioraLogoPink = '${_img}bomiora-logo-pink.png';

  /// 건강프로필 문진표 단계 아이콘 (SVG)
  static const String profile1 = '${_img}profile_1.svg';
  static const String profile2 = '${_img}profile_2.svg';
  static const String profile3 = '${_img}profile_3.svg';
  static const String profile4 = '${_img}profile_4.svg';
  static const String profile5 = '${_img}profile_5.svg';

  // 간편로그인 아이콘
  static const String loginNaver = '${_img}login_naver.png';
  static const String loginKakao = '${_img}login_kakao.png';
  static const String loginGoogle = '${_img}login_google.png';
  static const String loginApple = '${_img}login_apple.png'; 

  // 아이디/비밀번호 찾기 실패 아이콘
  static const String loginFail = '${_img}login_fail.png';

  // 비대면처방 제품 메인 페이지
  static const String productMain = '${_img}product_main_1.jpg';
  static const String productMainIcon1 = '${_img}product_main_icon1.svg';
  static const String productMainIcon2 = '${_img}product_main_icon2.svg';
  static const String productMainIcon3 = '${_img}product_main_icon3.svg';
  static const String productIntro = '${_img}product_main_intro.png';
  static const String productMainBottom1 = '${_img}product_main_bottom_1.png';
  static const String productMainBottom2 = '${_img}product_main_bottom_2.png';
  static const String productMainBottom3 = '${_img}product_main_bottom_3.png';
  static const String productMainBottom4 = '${_img}product_main_bottom_4.png';
}
