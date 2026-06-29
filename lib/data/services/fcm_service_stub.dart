/// FCM 서비스 스텁 (웹·데스크톱에서 Firebase 미사용)
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {}

  Future<String?> getFCMToken() async => null;

  Future<void> registerTokenWithServer() async {}

  Future<void> syncTopicsFromSettings() async {}

  Future<void> subscribeToTopic(String topic) async {}

  Future<void> unsubscribeFromTopic(String topic) async {}
}
