class ApiConstants {
  // 기본 URL - 실제 서버 URL로 변경 필요
  static const String baseUrl = 'https://your-api-server.com/api';
  
  // 인증 관련
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  
  // 사용자 관련
  static const String userProfile = '/user/profile';
  static const String updateProfile = '/user/profile';
  
  // 문진표 관련
  static const String questionnaire = '/questionnaire';
  static const String questionnaireByUser = '/questionnaire/user';
  
  // 건강 데이터 관련
  static const String healthData = '/health';
  static const String weightRecords = '/health/weight';
  static const String bloodPressureRecords = '/health/blood-pressure';
  static const String bloodSugarRecords = '/health/blood-sugar';
  static const String stepsRecords = '/health/steps';
  static const String menstrualCycleRecords = '/health/menstrual-cycle';
  
  // 쇼핑 관련
  static const String products = '/products';
  static const String categories = '/categories';
  static const String cart = '/cart';
  static const String orders = '/orders';
  
  // 쿠폰 관련
  static const String coupons = '/coupons';
  static const String userCoupons = '/coupons/user';
  
  // 마일리지 관련
  static const String mileage = '/mileage';
  static const String mileageHistory = '/mileage/history';
  
  // 리뷰 관련
  static const String reviews = '/reviews';
  static const String productReviews = '/reviews/product';
  
  // 공지사항 관련
  static const String notices = '/notices';
  static const String faq = '/faq';
  
  // 파일 업로드
  static const String upload = '/upload';
  static const String uploadImage = '/upload/image';
  
  // API 응답 상태 코드
  static const int success = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int internalServerError = 500;
  
  // 페이지네이션
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // 타임아웃 설정 (초)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;
}
