import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Cloud Messaging 서비스
/// 푸시 알림 초기화, 토큰 관리, 메시지 수신 처리
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// FCM 초기화
  Future<void> initialize() async {
    try {
      // 알림 권한 요청
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('📱 FCM 권한 상태: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // FCM 토큰 가져오기
        await _getToken();

        // 로컬 알림 초기화
        await _initializeLocalNotifications();

        // 포그라운드 메시지 수신 설정
        _configureForegroundNotification();

        // 백그라운드/종료 상태 메시지 핸들러 설정
        FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

        // 토큰 갱신 리스너
        _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

        // 알림 클릭 이벤트 처리
        _handleNotificationInteraction();

        print('✅ FCM 초기화 완료');
      } else {
        print('⚠️ 알림 권한이 거부되었습니다.');
      }
    } catch (e) {
      print('❌ FCM 초기화 실패: $e');
    }
  }

  /// FCM 토큰 가져오기
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print('🔑 FCM 토큰: $_fcmToken');

      // 토큰을 로컬 저장소에 저장
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
      }

      return _fcmToken;
    } catch (e) {
      print('❌ FCM 토큰 가져오기 실패: $e');
      return null;
    }
  }

  /// 토큰 갱신 처리
  Future<void> _handleTokenRefresh(String newToken) async {
    print('🔄 FCM 토큰 갱신: $newToken');
    _fcmToken = newToken;

    // 토큰을 로컬 저장소에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', newToken);

    // TODO: 서버에 새 토큰 전송
    await _sendTokenToServer(newToken);
  }

  /// 서버에 토큰 전송 (백엔드 API 연동 필요)
  Future<void> _sendTokenToServer(String token) async {
    try {
      // TODO: 백엔드 API 호출하여 토큰 저장
      // final response = await http.post(
      //   Uri.parse('${ApiConstants.baseUrl}/api/users/fcm-token'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'fcm_token': token}),
      // );
      print('📤 서버에 FCM 토큰 전송: $token');
    } catch (e) {
      print('❌ 토큰 전송 실패: $e');
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Android 알림 채널 생성
    await _createNotificationChannels();
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannels() async {
    // 높은 중요도 채널 (주문, 배송 알림)
    const highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel',
      '중요 알림',
      description: '주문, 배송 관련 중요 알림',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // 일반 알림 채널 (이벤트, 쿠폰)
    const defaultChannel = AndroidNotificationChannel(
      'default_channel',
      '일반 알림',
      description: '이벤트, 쿠폰 등 일반 알림',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    // 건강 알림 채널
    const healthChannel = AndroidNotificationChannel(
      'health_channel',
      '건강 알림',
      description: '체중 기록, 건강 프로필 리마인더',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highImportanceChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(defaultChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(healthChannel);
  }

  /// 포그라운드 메시지 수신 설정
  void _configureForegroundNotification() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 포그라운드 메시지 수신: ${message.messageId}');
      print('제목: ${message.notification?.title}');
      print('내용: ${message.notification?.body}');
      print('데이터: ${message.data}');

      // 포그라운드에서도 알림 표시
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    // 알림 타입에 따라 채널 선택
    String channelId = 'default_channel';
    if (data['type'] == 'order' || data['type'] == 'delivery') {
      channelId = 'high_importance_channel';
    } else if (data['type'] == 'health') {
      channelId = 'health_channel';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'high_importance_channel' ? '중요 알림' : '일반 알림',
      channelDescription: notification?.body ?? '',
      importance: channelId == 'high_importance_channel'
          ? Importance.high
          : Importance.defaultImportance,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification?.title ?? '알림',
      notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  /// 알림 클릭 이벤트 처리
  void _handleNotificationInteraction() {
    // 앱이 종료된 상태에서 알림 클릭
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationNavigation(message.data);
      }
    });

    // 앱이 백그라운드 상태에서 알림 클릭
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationNavigation(message.data);
    });
  }

  /// 알림 탭 처리 (로컬 알림)
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationNavigation(data);
    }
  }

  /// 알림 데이터 기반 화면 이동
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    print('🔔 알림 클릭 데이터: $data');

    final type = data['type'];
    final id = data['id'];

    // TODO: 알림 타입에 따라 해당 화면으로 이동
    switch (type) {
      case 'order':
        // 주문 상세 화면으로 이동
        print('주문 상세로 이동: $id');
        // Navigator.pushNamed(context, '/order-detail', arguments: id);
        break;
      case 'delivery':
        // 배송 조회 화면으로 이동
        print('배송 조회로 이동: $id');
        // Navigator.pushNamed(context, '/delivery-list');
        break;
      case 'health':
        // 건강 관리 화면으로 이동
        print('건강 관리로 이동');
        // Navigator.pushNamed(context, '/health-profile');
        break;
      case 'coupon':
        // 쿠폰 화면으로 이동
        print('쿠폰 화면으로 이동');
        // Navigator.pushNamed(context, '/coupon');
        break;
      case 'event':
        // 이벤트 상세 화면으로 이동
        print('이벤트 상세로 이동: $id');
        // Navigator.pushNamed(context, '/event-detail', arguments: id);
        break;
      default:
        print('알 수 없는 알림 타입: $type');
    }
  }

  /// 앱 배지 초기화
  /// TODO: flutter_app_badger 패키지 사용 필요
  Future<void> clearBadge() async {
    // await _firebaseMessaging.setApplicationIconBadgeNumber(0);
    // 최신 firebase_messaging에서는 이 메서드가 제거되었습니다.
    // flutter_app_badger 패키지를 사용하거나 플랫폼별 구현이 필요합니다.
    print('⚠️ 배지 초기화 기능은 추후 구현 예정입니다.');
  }

  /// 구독 (특정 토픽)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ 토픽 구독: $topic');
    } catch (e) {
      print('❌ 토픽 구독 실패: $e');
    }
  }

  /// 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ 토픽 구독 해제: $topic');
    } catch (e) {
      print('❌ 토픽 구독 해제 실패: $e');
    }
  }
}

/// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  print('🌙 백그라운드 메시지 수신: ${message.messageId}');
  print('제목: ${message.notification?.title}');
  print('내용: ${message.notification?.body}');
  print('데이터: ${message.data}');

  // 백그라운드에서도 필요한 처리 수행
  // 예: 로컬 데이터베이스 업데이트, 알림 카운트 증가 등
}

