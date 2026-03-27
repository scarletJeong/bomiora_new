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


  /// 앱 로고 (PNG)
  static const String bomioraLogo = '${_img}bomiora-logo.png';

  /// 건강프로필 문진표 단계 아이콘 (SVG)
  static const String profile1 = '${_img}profile_1.svg';
  static const String profile2 = '${_img}profile_2.svg';
  static const String profile3 = '${_img}profile_3.svg';
  static const String profile4 = '${_img}profile_4.svg';
  static const String profile5 = '${_img}profile_5.svg';
}
