class ApiEndpoints {
  // 인증 관련 (Spring Boot 서버)
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';
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
  
  // 리뷰 관련 (기존 Cafe24 서버)
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
  static const String weightRecords = '/api/health/weight';
  static const String menstrualCycleRecords = '/api/health/menstrual-cycle';
  static const String stepsRecords = '/api/health/steps';
  static const String healthStats = '/api/health/stats';
  
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
  
  // 상품 옵션 관련
  static String productOptions(String productId) => '/api/products/$productId/options';
  
  // 문의 관련
  static const String getMyContacts = '/api/contact/list';
  static const String getContactDetail = '/api/contact';
  static const String getContactReplies = '/api/contact';
  static const String createContact = '/api/contact/create';
}
