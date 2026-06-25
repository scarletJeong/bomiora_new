/// FCM 서비스 스텁 (웹용)
/// 웹 환경에서는 FCM을 사용하지 않음
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// FCM 초기화 (웹에서는 아무것도 하지 않음)
  Future<void> initialize() async {
  }

  /// FCM 토큰 가져오기 (웹에서는 null 반환)
  Future<String?> getFCMToken() async {
    return null;
  }

  /// 토픽 구독 (웹에서는 아무것도 하지 않음)
  Future<void> subscribeToTopic(String topic) async {
  }

  /// 토픽 구독 해제 (웹에서는 아무것도 하지 않음)
  Future<void> unsubscribeFromTopic(String topic) async {
  }

  /// 알림 설정 확인 (웹에서는 항상 false)
  Future<bool> checkNotificationSettings(String settingKey) async {
    return false;
  }

  /// 알림 설정 저장 (웹에서는 아무것도 하지 않음)
  Future<void> saveNotificationSetting(String settingKey, bool value) async {
  }
}

