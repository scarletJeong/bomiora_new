/// `pubspec.yaml`의 `assets:`에 `assets/img/`만 등록된 이미지 경로.
/// 새 이미지도 `assets/img/` 아래에 두고 여기에 상수로 추가하면 됩니다.
abstract final class AppAssets {
  AppAssets._();

  static const String _img = 'assets/img/';

  /* 0. 공통 */
  // 앱 로고 (SVG)
  static const String bomioraLogo = '${_img}bomiora-appbar-logo.svg';
  static const String bomioraPinkLogo = '${_img}bomiora-logo-pink.svg';
  static const String bomioraAppbarLogo = '${_img}bomiora-appbar-logo.svg';
  static const String bomioraBottomLogo = '${_img}bomiora-bottom-logo.png';

  // 앱바(app_bar_menu.dart) 아이콘
  static const String appbarSearchIcon = '${_img}appbar_menu_search.svg';
  static const String appbarAlarmIcon = '${_img}appbar_menu_alarm.svg';
  static const String appbarCartIcon = '${_img}appbar_menu_cart.svg';

  // 햄버거 메뉴 아이콘
  static const String menuIcon = '${_img}menu_icon.svg';

  // 메뉴 아이콘
  static const String menu_home_icon = '${_img}menu_home_icon.svg';  // 홈 
  static const String menu_health_icon = '${_img}menu_health_icon.svg';  // 문진표
  static const String menu_order_icon = '${_img}menu_order_icon.svg';  // 주문배송
  static const String menu_cart_icon = '${_img}menu_cart_icon.svg';  // 장바구니
  static const String menu_coupon_icon = '${_img}menu_coupon_icon.svg';  // 쿠폰
  static const String menu_point_icon = '${_img}menu_point_icon.svg';  // 포인트
  static const String menu_mypage_icon = '${_img}menu_mypage_icon.svg';  // 마이페이지
  static const String menu_QA_icon = '${_img}menu_QA_icon.svg';  // 1:1 문의

  // 네비게이션 아이콘
  static const String naviIcon1 = '${_img}navi_icon1.svg'; // 홈
  static const String naviIcon2 = '${_img}navi_icon2.svg'; // 건강대시보드
  static const String naviIcon3 = '${_img}navi_icon3.svg'; // 비대면 진료
  static const String naviIcon4 = '${_img}navi_icon4.svg'; // 문진표
  static const String naviIcon5 = '${_img}navi_icon5.svg'; // MY PAGE

  // 푸터 아이콘
  static const String footerIcon1 = '${_img}footer_icon1.svg'; // 로고1
  static const String footerIcon2 = '${_img}footer_icon2.svg'; // 로고2 _글씨

  // 앱바 - 검색 아이콘
  static const String searchIcon = '${_img}search_icon.svg';
  // 앱바 - 설정 아이콘
  static const String appbarSettingsIcon = '${_img}appbar_menu_settings.svg';

  // 사진추가하기 회색카드 아이콘
  static const String addPhotoIcon = '${_img}add_photo_icon.svg';
  
  // 예약시간 변경 예약일자 핑크 달력 아이콘
  static const String reservationCalendarIcon = '${_img}reservation_calendar_icon.svg';

  // 설정 아이콘
  static const String settingsIcon = '${_img}mypage_settings_icon.svg';

  // 공통 토스트 오버레이 체크 아이콘
  static const String commonToastOverlay = '${_img}commonToastOverlay.svg';

  // 안내 아이콘
  static const String guideIcon = '${_img}guide_icon.svg';
  
  /* 1. 홈 */
  // 리뷰카드 오버레이 (PNG) assets/img/review_card_overlay`
  static const String reviewCardOverlay = '${_img}review_card_overlay.png';

  // 검색 - 결과 없음 아이콘
  static const String searchEmptyIcon = '${_img}search_empty_icon.svg';

  /* 2. 회원가입/로그인 */
  // 간편로그인 아이콘
  static const String loginNaver = '${_img}login_naver.svg';
  static const String loginKakao = '${_img}login_kakao.svg';
  static const String loginGoogle = '${_img}login_google.svg';
  static const String loginApple = '${_img}login_apple.svg'; 

  // 아이디/비밀번호 찾기 실패 아이콘
  static const String loginFail = '${_img}login_fail.png';


  /* 3. 제품 상세보기 */
  // 제품 상세보기 하단 - 기관인증 아이콘
  static const String productDetailCertification = '${_img}product_detail_certification.svg';
  
  /* 4. 건강대시보드 */
  // 건강대시보드 연동 아이콘
  static const String healthConnectApple = '${_img}connect_apple.svg';
  static const String healthConnectSamsung = '${_img}connect_samsung.svg';
  static const String healthConnectGoogle = '${_img}connect_google.svg';

  // 그래프 확대 아이콘
  static const String healthZoomin = '${_img}graph_zoomin.svg';

  // 위아래 아이콘콘
  static const String arrowUp = '${_img}arrow_up.svg';
  static const String arrowDown = '${_img}arrow_down.svg';

  // 달력 아이콘
  static const String calendarIcon = '${_img}health_calendar.svg';

  // 메인 카드 아이콘   
  static const String mainCardIconHeartRate = '${_img}health_heart_rate.svg';
  static const String mainCardIconBloodPressure = '${_img}health_blood_pressure.svg';
  static const String mainCardIconBloodSugar = '${_img}health_blood_sugar.svg';
  static const String mainCardIconMenstrual = '${_img}health_menstrual.svg';

  // 생리주기 추천 카드 아이콘
  static const String menstrualConditionCheckIcon = '${_img}health_menstrual.svg';
  static const String menstrualBomioraPickIcon = '${_img}thumb_up_icon.svg';

  // 걸음수 카드 아이콘
  static const String stepsDown = '${_img}step_arrow_down.svg';
  static const String stepsUp = '${_img}step_arrow_up.svg';
  static const String stepsDistanceCard = '${_img}step_distanceCard.svg';
  static const String stepsCaloriesCard = '${_img}step_caloriesCard.svg';

  // 식사 카드 아이콘
  static const String foodCaloriesCard = '${_img}food_nothingCard.svg';

  // 음식 촬영 아이콘 
  static const String foodCamera = '${_img}food_camera.svg';

  /* 5. 스토어 */
  // 빠른 탭 (메인 퀵 탭) 아이콘
  static const String quickTabIcon1 = '${_img}main_quick_tap_icon1.svg'; // 비대면 진료
  static const String quickTabIcon2 = '${_img}main_quick_tap_icon2.svg'; // 문진표
  static const String quickTabIcon3 = '${_img}main_quick_tap_icon3.svg'; // 건강대시보드
  static const String quickTabIcon4 = '${_img}main_quick_tap_icon4.svg'; // 스토어

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

  // 헬스케어 스토어(일반 상품) 메인 페이지
  static const String generalMainIcon1 = '${_img}general_main_icon1.svg'; // 다이어트
  static const String generalMainIcon2 = '${_img}general_main_icon2.svg'; // 디톡스
  static const String generalMainIcon3 = '${_img}general_main_icon3.svg'; // 건강/면역
  static const String generalMainIcon4 = '${_img}general_main_icon4.svg'; // 심신안정
  static const String generalMainIcon5 = '${_img}general_main_icon5.svg'; // 스킨케어
  static const String generalMainIcon6 = '${_img}general_main_icon6.svg'; // 헤어/탈모

  static const String generalMainBanner = '${_img}general_main_banner1.png';
  static const String generalMainBanner2 = '${_img}general_main_banner2.png';
 
  // 쇼핑몰 공유하기 아이콘
  static const String shoppingShareIcon = '${_img}shopping_share_icon.svg';
  
  /* 6. 마이페이지 */
  // 마이페이지 - 설정 아이콘 및 포토프로필 아이콘
  static const String mypagePersonalInfoSettingsIcon = '${_img}mypage_personal_info_settings_icon.svg';
  static const String mypagePhotoProfileIcon = '${_img}mypage_photo_profile_icon.svg';

  // 마이페이지 주문내역~내쿠폰까지 통계 카드 아이콘/테두리
  static const String deliveryMain = '${_img}deliveryMain.svg';
  static const String couponMain = '${_img}couponMain.svg';
  static const String pointMain = '${_img}pointMain.svg';
  static const String mypageMenuBorder = '${_img}mypage_menu_border.svg';
  
  // 포인트 화면 등에서 사용하는 포인트 아이콘
  static const String pointIcon = '${_img}point_icon.svg';

  // 쿠폰 화면 등에서 사용하는 쿠폰 아이콘
  static const String couponIcon = '${_img}coupon_icon.svg';

  // 마이페이지 - 내 리뷰 도움쿠폰 카드
  static const String myReviewCouponIcon = '${_img}myReview_couponCard_icon.svg';
  static const String myReviewCouponCardDownload = '${_img}myReview_couponCard_download.svg';

  // 마이페이지 - 리뷰 별점 아이콘
  static const String reviewStar = '${_img}review_star.svg';

  /* 7. 건강프로필 */
  // 건강프로필 문진표 단계 아이콘 (SVG)
  static const String profile1 = '${_img}profile_1.svg';
  static const String profile2 = '${_img}profile_2.svg';
  static const String profile3 = '${_img}profile_3.svg';
  static const String profile4 = '${_img}profile_4.svg';
  static const String profile5 = '${_img}profile_5.svg';

  // 회원 탈퇴 아이콘
  static const String cancelMemberIcon = '${_img}cancel_member_icon.svg';
  // 회원 탈퇴 설명 아이콘
  static const String cancelIcon1 = '${_img}cancel_icon1.svg';
  
  
  /* 8. 결제 */
  // 결제 화면 - 결제수단 아이콘
  static const String payCredit = '${_img}pay_credit.svg';
  static const String payCash = '${_img}pay_cash.svg';
  static const String escrow = '${_img}escrow.png';


  /*9. 은행 아이콘 */
  static const String IBKIcon = '${_img}bankIcon_IBK.svg';
  static const String KBIcon = '${_img}bankIcon_KB.svg';
  static const String KEBIcon = '${_img}bankIcon_KEB.svg';
  static const String NHIcon = '${_img}bankIcon_NH.svg';
  static const String SCIcon = '${_img}bankIcon_SC.svg';
  static const String BNKIcon = '${_img}bankIcon_BNK.svg';
  /// 대구·부산·경남 공통
  static const String DGIcon = '${_img}bankIcon_DG.svg';
  static const String SHIcon = '${_img}bankIcon_SH.svg';
  static const String JJIcon = '${_img}bankIcon_JJ.svg';
  /// 전북·광주 공통 (광주는 JBIcon 사용)
  static const String JBIcon = '${_img}bankIcon_JB.svg';
  static const String CITIIcon = '${_img}bankIcon_CITI.svg';
  static const String WOORIIcon = '${_img}bankIcon_WOORI.svg';
  static const String POSTIcon = '${_img}bankIcon_POST.svg';
  static const String KAKAOIcon = '${_img}bankIcon_KAKAO.svg';
  static const String KIcon = '${_img}bankIcon_K.svg';
  static const String TOSSIcon = '${_img}bankIcon_TOSS.svg';

  /* 10. 건강콘텐츠 */
  // 엄지척 아이콘 - 콘텐츠 추천
  static const String thumbUpIcon = '${_img}thumb_up_icon.svg';
  static const String thumbUpIconFilled = '${_img}thumb_up_icon_filled.svg';

  // 하트 아이콘 - 콘텐츠 찜
  static const String heartIcon = '${_img}content_heart_icon.svg';
  static const String heartIconFilled = '${_img}content_heart_icon_filled.svg';

  // 빈 화면 아이콘 — '로그인 후 이용 가능합니다' / '~가 없습니다' 문구 위
  static const String emptyWishlistIcon = '${_img}empty_wishlist_icon.svg'; // 찜목록
  static const String emptyAddressIcon = '${_img}empty_address_icon.svg'; // 배송지 관리
  static const String emptyReviewIcon = '${_img}empty_review_icon.svg'; // 내 리뷰
  static const String emptyQAIcon = '${_img}empty_QAicon.svg'; // 1:1 문의
  static const String emptyRefundIcon = '${_img}empty_refund_icon.svg'; // 환불계좌
  static const String emptyHealthIcon = '${_img}empty_health_icon.svg'; // 문진표 관리

  static const String emptyAlarmIcon = '${_img}empty_alarm_icon.svg'; // 알림센터
  static const String emptySettingIcon = '${_img}empty_setting_icon.svg'; // 설정

  static const String emptyDeliveryIcon = '${_img}empty_delivery_icon.svg'; // 주문내역
  static const String emptyCouponIcon = '${_img}empty_coupon_icon.svg'; // 쿠폰
  static const String emptyPointIcon = '${_img}empty_point_icon.svg'; // 포인트
  static const String emptyCartIcon = '${_img}empty_cart_icon.svg'; // 장바구니(처방제품)
  static const String emptyCartGeneralIcon = '${_img}empty_cart_general_icon.svg'; // 장바구니(일반 상품)

  static const String emptyHealthDashboardIcon = '${_img}empty_health_dashboard_icon.svg'; // 건강대시보드 기록 없음
  static const String emptyCategoryIcon = '${_img}empty_category_icon.svg'; // 카테고리 내 상품 없음
  static const String emptyProductReviewIcon = '${_img}empty_product_review_icon.svg'; // 상품 상세 내 리뷰 없음
  static const String emptyContentIcon = '${_img}empty_content_icon.svg'; // 콘텐츠/게시글 빈 카드
  static const String emptySearchIcon = '${_img}empty_search_icon.svg'; // 검색 결과 없음
  
  static const String emptyNoticeIcon = '${_img}empty_notice_icon.svg'; // 공지사항 빈 카드
  static const String emptyEventIcon = '${_img}empty_event_icon.svg'; // 이벤트 빈 카드


}
