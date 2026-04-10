class ApiEndpoints {
  // 인증 관련 (Spring Boot 서버)
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String checkEmail = '/api/auth/check-email';
  static const String logout = '/api/auth/logout';
  static const String findId = '/api/auth/find-id';
  static const String resetPassword = '/api/auth/reset-password';
  static const String withdraw = '/api/auth/withdraw';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String verifyToken = '/api/auth/verify';
  
  // 상품 관련 (기존 Cafe24 서버)
  static const String popularProducts = '/api/products/popular';
  static const String newProducts = '/api/products/new';
  static const String productDetail = '/api/products/detail';
  static String productListByCategory(String categoryId, {String? productKind}) {
    String endpoint = '/api/products/list?ca_id=$categoryId';
    if (productKind != null && productKind.isNotEmpty) {
      endpoint += '&it_kind=$productKind';
    }
    return endpoint;
  }
  
  // 장바구니 관련 (기존 Cafe24 서버)
  static const String addToCart = '/api/cart/add';
  static const String getCart = '/api/cart';
  static const String updateCartItem = '/api/cart/update';
  static const String removeCartItem = '/api/cart/remove';
  static const String generateOrderId = '/api/cart/generate-order-id';
  
  // 찜 관련 (기존 Cafe24 서버)
  static const String getWishList = '/api/wish/list';
  static const String addToWish = '/api/wish/toggle';
  static const String removeFromWish = '/api/wish/remove';
  
  // 리뷰 관련 — 메인 홈 베스트 리뷰는 Node `bomiora_main_review` (쿼리: ?size=8)
  static const String mainHomeReviews = '/api/user/reviews/main';
  /// @deprecated Cafe24 구 경로. 메인 홈은 [mainHomeReviews] 사용.
  static const String mainReviews = '/api/reviews/main';
  static const String productReviews = '/api/reviews/product';
  static const String addReview = '/api/reviews/add';
  static String productReviewsByKind(String productId, {String? reviewKind}) {
    String endpoint = '/api/reviews/product?it_id=$productId';
    if (reviewKind != null && reviewKind.isNotEmpty) {
      endpoint += '&is_rvkind=$reviewKind';
    }
    return endpoint;
  }
  
  // 체험단 관련 (기존 Cafe24 서버)
  static const String testerItems = '/api/tester/items';
  static const String applyTester = '/api/tester/apply';
  
  // 사용자 관련 (Spring Boot 서버)
  static const String userProfile = '/api/user/profile';
  static const String userOrders = '/api/user/orders';
  
  // 건강 관리 관련 (향후 확장용)
  static const String bloodSugarRecords = '/api/health/blood-sugar';
  static const String bloodPressureRecords = '/api/health/blood-pressure';
  static const String heartRateRecords = '/api/health/heart-rate';
  static const String weightRecords = '/api/health/weight';
  static const String menstrualCycleRecords = '/api/health/menstrual-cycle';
  /// 목표설정 (현재/목표 체중, 일일 목표 걸음) — Node: POST/GET latest
  static const String healthGoal = '/api/health/health-goal';
  static String healthGoalLatest(String mbId) =>
      '/api/health/health-goal/latest?mb_id=${Uri.encodeComponent(mbId)}';
  static const String stepsRecords = '/api/health/steps';

  /// Node 걸음 API — 일별 총 걸음 (`bomiora_back`: GET /api/steps/daily-total)
  static String stepsDailyTotal({required String mbId, required String dateYyyyMmDd}) =>
      '/api/steps/daily-total?mb_id=${Uri.encodeComponent(mbId)}&date=${Uri.encodeComponent(dateYyyyMmDd)}';

  static String stepsDailyRange({
    required String mbId,
    required String startYyyyMmDd,
    required String endYyyyMmDd,
  }) =>
      '/api/steps/daily-range?mb_id=${Uri.encodeComponent(mbId)}&start=${Uri.encodeComponent(startYyyyMmDd)}&end=${Uri.encodeComponent(endYyyyMmDd)}';

  static String stepsMonthlyTotals({required String mbId, required int year}) =>
      '/api/steps/monthly-totals?mb_id=${Uri.encodeComponent(mbId)}&year=$year';

  /// 주간/월간/통계 등 기존 경로 (userId = 숫자 회원 ID)
  static String stepsStatistics(int userId) => '/api/steps/statistics/$userId';
  static const String healthStats = '/api/health/stats';
  static String foodSearch(String q, {int limit = 20, int offset = 0}) =>
      '/api/health/food/search?q=${Uri.encodeComponent(q)}&limit=$limit&offset=$offset';
  static String foodRecords(String recordDate) =>
      '/api/health/food/records?record_date=$recordDate';
  static const String foodRecordCreate = '/api/health/food/records';
  static String foodRecordItems(String foodRecordId) =>
      '/api/health/food/records/$foodRecordId/items';
  static String foodRecordItemDelete(String foodRecordId, String itemId) =>
      '/api/health/food/records/$foodRecordId/items/$itemId';

  // 포인트 관련
  static String userPoint(String userId) => '/api/user/point?mb_id=$userId';
  static String pointHistory(String userId) => '/api/user/point/history?mb_id=$userId';
  static const String config = '/api/config';
  
  // 쿠폰 관련
  static String userCoupons(String userId) => '/api/user/coupons?mb_id=$userId';
  static String availableCoupons(String userId) => '/api/user/coupons/available?mb_id=$userId';
  static String usedCoupons(String userId) => '/api/user/coupons/used?mb_id=$userId';
  static String expiredCoupons(String userId) => '/api/user/coupons/expired?mb_id=$userId';
  static const String registerCoupon = '/api/user/coupons/register';
  static const String downloadHelpCoupon = '/api/user/coupons/help-coupon';
  
  // 상품 옵션 관련
  static String productOptions(String productId) => '/api/products/$productId/options';
  
  // 문의 관련
  static const String getMyContacts = '/api/contact/list';
  static const String getContactDetail = '/api/contact';
  static const String getContactReplies = '/api/contact';
  static const String createContact = '/api/contact/create';
  static String updateContact(int wrId) => '/api/contact/$wrId';
  static String deleteContact(int wrId) => '/api/contact/$wrId';
  
  // 이벤트 관련
  static const String getActiveEvents = '/api/event/active';
  static const String getEndedEvents = '/api/event/ended';
  static const String getEventDetail = '/api/event';
}
