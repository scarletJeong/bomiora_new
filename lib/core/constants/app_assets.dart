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
  static const String bomioraPinkLogo = '${_img}bomiora-logo-pink.png';
  static const String bomioraAppbarLogo = '${_img}bomiora-appbar-logo.png';
  static const String bomioraBottomLogo = '${_img}bomiora-bottom-logo.png';

  // 앱바(app_bar_menu.dart) 아이콘
  static const String appbarSearchIcon = '${_img}appbar_menu_search.svg';
  static const String appbarAlarmIcon = '${_img}appbar_menu_alarm.svg';
  static const String appbarCartIcon = '${_img}appbar_menu_cart.svg';

  // 네비게이션 아이콘
  static const String naviIcon1 = '${_img}navi_icon1.svg'; // 홈
  static const String naviIcon2 = '${_img}navi_icon2.svg'; // 건강대시보드
  static const String naviIcon3 = '${_img}navi_icon3.svg'; // 비대면 진료
  static const String naviIcon4 = '${_img}navi_icon4.svg'; // 문진표
  static const String naviIcon5 = '${_img}navi_icon5.svg'; // MY PAGE

  // 푸터 아이콘
  static const String footerIcon1 = '${_img}footer_icon1.svg'; // 로고1
  static const String footerIcon2 = '${_img}footer_icon2.svg'; // 로고2 _글씨

  // 메인 퀵 탭 아이콘
  static const String quickTabIcon1 = '${_img}main_quick_tap_icon1.svg'; // 비대면 진료
  static const String quickTabIcon2 = '${_img}main_quick_tap_icon2.svg'; // 문진표
  static const String quickTabIcon3 = '${_img}main_quick_tap_icon3.svg'; // 건강대시보드
  static const String quickTabIcon4 = '${_img}main_quick_tap_icon4.svg'; // 스토어

  // 회원 탈퇴 아이콘

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

  // 제품 상세보기 하단 - 기관인증 아이콘
  static const String productDetailCertification = '${_img}product_detail_certification.svg';
  
  // 건강대시보드 그래프 확대 아이콘
  static const String healthZoomin = '${_img}graph_zoomin.svg';

  // 헬스케어 스토어(일반 상품) 메인 페이지
  static const String generalMainIcon1 = '${_img}general_main_icon1.svg'; // 다이어트
  static const String generalMainIcon2 = '${_img}general_main_icon2.svg'; // 디톡스
  static const String generalMainIcon3 = '${_img}general_main_icon3.svg'; // 건강/면역
  static const String generalMainIcon4 = '${_img}general_main_icon4.svg'; // 심신안정
  static const String generalMainIcon5 = '${_img}general_main_icon5.svg'; // 스킨케어
  static const String generalMainIcon6 = '${_img}general_main_icon6.svg'; // 헤어/탈모

  static const String generalMainBanner = '${_img}general_main_banner1.png';
  static const String generalMainBanner2 = '${_img}general_main_banner2.png';

  // 회원 탈퇴 아이콘
  static const String cancelMemberIcon = '${_img}cancel_member_icon.svg';

  // 건강대시보드 - 생리주기 추천 카드 아이콘
  static const String menstrualIcon1 = '${_img}menstrual_icon1.png';
  static const String menstrualIcon2 = '${_img}menstrual_icon2.png';
  static const String menstrualIcon3 = '${_img}menstrual_icon3.png';

  // 결제 화면 - 결제수단 아이콘
  static const String payCredit = '${_img}pay_credit.svg';
  static const String payCash = '${_img}pay_cash.svg';
  static const String escrow = '${_img}escrow.png';
}
