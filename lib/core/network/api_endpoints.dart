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
  
  // 장바구니 관련 (기존 Cafe24 서버)
  static const String addToCart = '/api/cart/add';
  static const String getCart = '/api/cart';
  static const String updateCartItem = '/api/cart/update';
  static const String removeCartItem = '/api/cart/remove';
  
  // 리뷰 관련 (기존 Cafe24 서버)
  static const String mainReviews = '/api/reviews/main';
  static const String productReviews = '/api/reviews/product';
  static const String addReview = '/api/reviews/add';
  
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
  static const String healthStats = '/api/health/stats';
}
