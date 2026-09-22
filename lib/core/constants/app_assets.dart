/// `pubspec.yaml`의 `assets:`에 `assets/img/`·하위 폴더를 등록한 이미지 경로.
/// 새 이미지도 `assets/img/` 아래(필요하면 하위 폴더)에 두고 여기에 상수로 추가하면 됩니다.
abstract final class AppAssets {
  AppAssets._();

  static const String _img = 'assets/img/';
  static const String _bank = '${_img}bank/';

  /* 0. 공통 */
  // 앱 로고 (SVG)
  static const String bomioraPinkLogo = '${_img}bomiora-logo-pink.svg';
  static const String bomioraAppbarLogo = '${_img}bomiora-appbar-logo.svg';

  // 앱바(app_bar_menu.dart) 아이콘
  static const String appbarSearchIcon = '${_img}appbar_menu_search.svg'; // 검색
  static const String appbarAlarmIcon = '${_img}appbar_menu_alarm.svg'; // 알림
  static const String appbarCartIcon = '${_img}appbar_menu_cart.svg'; // 장바구니
  static const String appbarSettingsIcon = '${_img}appbar_menu_settings.svg'; // 설정

  // 스플래시 화면
  static const String splashScreen = '${_img}splash_screen.svg';
  static const String splashIcon = '${_img}splash_icon.svg';

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

  // 토스트 오버레이 체크 아이콘
  static const String commonToastOverlay = '${_img}commonToastOverlay.svg';

  // 사진추가하기 회색카드 아이콘
  static const String addPhotoIcon = '${_img}add_photo_icon.svg';

  // 알림센터 - 알림설정 아이콘
  static const String settingsIcon = '${_img}mypage_settings_icon.svg'; 

  // 안내 아이콘
  static const String guideIcon = '${_img}guide_icon.svg';

  /* 검색 */
  // 결과 없음 아이콘
  static const String searchEmptyIcon = '${_img}search_empty_icon.svg';
  // 검색 입력칸 버튼 아이콘
  static const String searchIcon = '${_img}search_icon.svg'; // 검색
  // 검색 팝업 닫기 아이콘
  static const String popupCloseIcon = '${_img}popup_close_icon.svg';



  /* 1. 회원가입/로그인 */
  // 간편로그인 아이콘
  static const String loginNaver = '${_img}login_naver.svg';
  static const String loginKakao = '${_img}login_kakao.svg';
  static const String loginApple = '${_img}login_apple.svg'; 

  // 아이디/비밀번호 찾기 실패 아이콘
  static const String loginFail = '${_img}login_fail.svg';

  // 회원가입 완료 - 바로가기 카드 아이콘
  static const String signupComplete = '${_img}signup_complete_health_profile.svg'; //문진표바로가기
  static const String signupCompleteHealthProduct = '${_img}signup_complete_health.svg'; //비대면진료 제품 바로가기
  static const String signupCompleteShopping = '${_img}signup_complete_shopping.svg'; //쇼핑몰 바로가기
  static const String signupCompleteHealthDashboard = '${_img}signup_complete_health_dashboard.svg'; //건강대시보드 바로가기


  /* 2. 소개글 */
  static const String productMain = '${_img}product_main_1.jpg';

  static const String productMainIcon1 = '${_img}product_main_icon1.svg';
  static const String productMainIcon2 = '${_img}product_main_icon2.svg';
  static const String productMainIcon3 = '${_img}product_main_icon3.svg';

  // 대표님 사진
  static const String productIntro = '${_img}product_main_intro.png';
  static const String productMainBottom1 = '${_img}product_main_bottom_1.png';
  static const String productMainBottom2 = '${_img}product_main_bottom_2.png';
  static const String productMainBottom3 = '${_img}product_main_bottom_3.png';
  static const String productMainBottom4 = '${_img}product_main_bottom_4.png';

  // 카테고리 아이콘
  static const String generalMainIcon1 = '${_img}general_main_icon1.svg'; // 다이어트
  static const String generalMainIcon2 = '${_img}general_main_icon2.svg'; // 디톡스
  static const String generalMainIcon3 = '${_img}general_main_icon3.svg'; // 건강/면역
  static const String generalMainIcon4 = '${_img}general_main_icon4.svg'; // 심신안정
  static const String generalMainIcon5 = '${_img}general_main_icon5.svg'; // 헤어/탈모


  /* 3. 쇼핑몰 */
  // 공유하기 아이콘
  static const String shoppingShareIcon = '${_img}shopping_share_icon.svg';

  // 기관인증 아이콘 (제품 상세보기 하단 )
  static const String productDetailCertification = '${_img}product_detail_certification.svg';
    
  // 서포터 리뷰 도움쿠폰 카드
  static const String myReviewCouponIcon = '${_img}myReview_couponCard_icon.svg';
  static const String myReviewCouponCardDownload = '${_img}myReview_couponCard_download.svg';


  /* 4. 건강대시보드 */
  // 건강대시보드 연동 아이콘
  static const String healthConnectApple = '${_img}connect_apple.svg';
  static const String healthConnectSamsung = '${_img}connect_samsung.svg';

  // 그래프 확대 아이콘
  static const String healthZoomin = '${_img}graph_zoomin.svg';

  // 위아래 아이콘
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


  /* 5. 마이페이지 */
  // 포토 프로필 사람 아이콘
  static const String mypagePhotoProfileIcon = '${_img}mypage_photo_profile_icon.svg';

  // 통계 카드 아이콘 + 테두리
  static const String deliveryMain = '${_img}deliveryMain.svg';
  static const String couponMain = '${_img}couponMain.svg';
  static const String pointMain = '${_img}pointMain.svg';
  static const String mypageMenuBorder = '${_img}mypage_menu_border.svg';

   // 회원 탈퇴 아이콘
  static const String cancelMemberIcon = '${_img}cancel_member_icon.svg';
  // 회원 탈퇴 설명 아이콘
  static const String cancelIcon1 = '${_img}cancel_icon1.svg';
  

  /* 6. 결제 */
  // 결제 화면 - 결제수단 아이콘
  static const String payCredit = '${_img}pay_credit.svg';
  static const String payCash = '${_img}pay_cash.svg';
  static const String escrow = '${_img}escrow.png';

  // 결제 완료 _ 진료예약 카드 아이콘
  static const String paymentCompleteReservationDateIcon = '${_img}payment_complete_reservation_date_icon.svg'; // 날짜 - 달력아이콘
  static const String paymentCompleteReservationTimeIcon = '${_img}payment_complete_reservation_time_icon.svg'; // 시간 - 시계아이콘
  static const String paymentCompleteReservationDoctorIcon = '${_img}payment_complete_reservation_doctor_icon.svg'; // 정대진 - 인간아이콘콘


  /* 7. 건강콘텐츠 */
  // 엄지척 아이콘 - 콘텐츠 추천
  static const String thumbUpIcon = '${_img}thumb_up_icon.svg';
  static const String thumbUpIconFilled = '${_img}thumb_up_icon_filled.svg';

  // 하트 아이콘 - 콘텐츠 찜
  static const String heartIcon = '${_img}content_heart_icon.svg';
  static const String heartIconFilled = '${_img}content_heart_icon_filled.svg';


  /* 8. 빈 화면 */
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

  static const String emptyCategoryIcon = '${_img}empty_category_icon.svg'; // 카테고리 내 상품 없음
  static const String emptyProductReviewIcon = '${_img}empty_product_review_icon.svg'; // 상품 상세 내 리뷰 없음
  static const String emptyContentIcon = '${_img}empty_content_icon.svg'; // 콘텐츠/게시글 빈 카드
  static const String emptySearchIcon = searchEmptyIcon; // 검색 결과 없음
  
  static const String emptyNoticeIcon = '${_img}empty_notice_icon.svg'; // 공지사항 빈 카드
  static const String emptyEventIcon = '${_img}empty_event_icon.svg'; // 이벤트 빈 카드


  /*9. 은행 아이콘 (`assets/img/bank/`) */
  static const String KBIcon = '${_bank}bankIcon_KB.svg';   // 국민은행
  static const String SHIcon = '${_bank}bankIcon_SH.svg';   // 신한은행
  static const String WOORIIcon = '${_bank}bankIcon_WOORI.svg'; // 우리은행
  static const String HANAIcon = '${_bank}bankIcon_HANA.svg'; // 하나은행

  static const String NHIcon = '${_bank}bankIcon_NH.svg';   // 농협은행 
  static const String IBKIcon = '${_bank}bankIcon_IBK.svg'; // 기업은행
  static const String KAKAOIcon = '${_bank}bankIcon_KAKAO.svg'; // 카카오뱅크
  static const String KIcon = '${_bank}bankIcon_K.svg';         // 케이뱅크
  static const String TOSSIcon = '${_bank}bankIcon_TOSS.png';   // 토스 

  static const String BNKIcon = '${_bank}bankIcon_BNK.svg'; //부산/경남 은행 
  static const String DGBIcon = '${_bank}bankIcon_DGB.svg'; // 대구 은행
  static const String JBIcon = '${_bank}bankIcon_JB.svg';   // 광주/전북은행
  static const String JJIcon = '${_bank}bankIcon_JJ.svg';   // 제주은행

  static const String SUHUIcon = '${_bank}bankIcon_SUHUIcon.svg'; // 수협은행
  static const String POSTIcon = '${_bank}bankIcon_POST.svg';   // 우체국
  static const String SCIcon = '${_bank}bankIcon_SC.svg';       // SC제일은행
  static const String CITIIcon = '${_bank}bankIcon_CITI.svg';   // 씨티은행

  /// 환불 계좌 등 은행명 → 아이콘 경로
  static String? bankIconForName(String bankName) {
    final n = bankName.trim();
    if (n.isEmpty) return null;
    if (n.contains('국민')) return KBIcon;
    if (n.contains('신한')) return SHIcon;
    if (n.contains('수협')) return SUHUIcon;
    if (n.contains('우리')) return WOORIIcon;
    if (n.contains('하나')) return HANAIcon;
    if (n.contains('농협')) return NHIcon;
    if (n.contains('기업')) return IBKIcon;
    if (n.contains('카카오')) return KAKAOIcon;
    if (n.contains('케이뱅크')) return KIcon;
    if (n.contains('토스')) return TOSSIcon;
    if (n.contains('대구')) return DGBIcon;
    if (n.contains('부산') || n.contains('경남')) return BNKIcon;
    if (n.contains('광주') || n.contains('전북')) return JBIcon;
    if (n.contains('제주')) return JJIcon;
    if (n.contains('우체국')) return POSTIcon;
    if (n.contains('SC제일') || n.contains('제일')) return SCIcon;
    if (n.contains('씨티')) return CITIIcon;
    return null;
  }

  /// 아이콘 SVG 여백이 달라 보이는 크기를 맞춘다.
  static double bankIconVisualScale(String bankName) {
    final n = bankName.trim();
    if (n.contains('신한')) return 0.7;
    if (n.contains('우리')) return 1.56;
    if (n.contains('제주')) return 1.52;
    if (n.contains('케이뱅크')) return 1.5;
    if (n.contains('국민')) return 1.6;
    if (n.contains('농협')) return 1.6;
    if (n.contains('하나')) return 1.6;
    if (n.contains('기업')) return 1.6;
    if (n.contains('씨티')) return 0.8;
    if (n.contains('제일')) return 1.3;
    if (n.contains('수협')) return 0.86;
    if (n.contains('우체국')) return 1.15;
    if (n.contains('토스')) return 1.15;
    if (n.contains('대구')) return 1.15;
    return 1.0;
  }
}
