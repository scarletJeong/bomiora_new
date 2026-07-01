import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/navigation/app_navigator_key.dart';
import 'notification_inbox_service.dart';
import 'notification_service.dart';

/// Firebase Cloud Messaging — Android/iOS 전용
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _requestAndroidNotificationPermission();

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final allowed = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return;

      await _initializeLocalNotifications();
      _configureForegroundNotification();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);
      _handleNotificationInteraction();

      await _getToken();
      await registerTokenWithServer();
      await _syncTopicsFromSettings();

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] initialize 실패: $e');
    }
  }

  Future<void> _requestAndroidNotificationPermission() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<String?> getFCMToken() async {
    if (_fcmToken != null) return _fcmToken;
    return _getToken();
  }

  Future<void> registerTokenWithServer() async {
    final token = await getFCMToken();
    if (token == null || token.isEmpty) return;
    await NotificationService.registerFcmToken(token);
  }

  Future<void> syncTopicsFromSettings() => _syncTopicsFromSettings();

  Future<void> _syncTopicsFromSettings() async {
    try {
      final settings = await NotificationService.loadSettings();
      if (settings.orderAgree) {
        await subscribeToTopic('orders');
      } else {
        await unsubscribeFromTopic('orders');
      }
      if (settings.marketingAgree && settings.appPushAgree) {
        await subscribeToTopic('marketing');
      } else {
        await unsubscribeFromTopic('marketing');
      }
    } catch (_) {}
  }

  Future<String?> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('[FCM] getToken 실패: $e');
      return null;
    }
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    _fcmToken = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', newToken);
    await NotificationService.registerFcmToken(newToken);
  }

  Future<void> _initializeLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'high_importance_channel',
        '중요 알림',
        description: '주문, 배송 관련 중요 알림',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'default_channel',
        '일반 알림',
        description: '이벤트, 쿠폰 등 일반 알림',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'health_channel',
        '건강 알림',
        description: '체중 기록, 건강 프로필 리마인더',
        importance: Importance.defaultImportance,
      ),
    ];

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in channels) {
      await android?.createNotificationChannel(channel);
    }
  }

  void _configureForegroundNotification() {
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null || message.data.isNotEmpty) {
        _showLocalNotification(message);
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final type = data['type']?.toString() ?? '';

    await NotificationInboxService.addFromFcm(
      data: Map<String, dynamic>.from(data),
      title: notification?.title,
      body: notification?.body,
    );

    var channelId = 'default_channel';
    if (type == 'order' || type == 'delivery') {
      channelId = 'high_importance_channel';
    } else if (type == 'health') {
      channelId = 'health_channel';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'high_importance_channel' ? '중요 알림' : '일반 알림',
      importance: channelId == 'high_importance_channel'
          ? Importance.high
          : Importance.defaultImportance,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      message.hashCode,
      notification?.title ?? data['title']?.toString() ?? '알림',
      notification?.body ?? data['body']?.toString() ?? '',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  void _handleNotificationInteraction() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _scheduleNavigation(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _scheduleNavigation(message.data);
    });
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = jsonDecode(response.payload!);
      if (data is Map) {
        _scheduleNavigation(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  void _scheduleNavigation(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationNavigation(data);
    });
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final type = data['type']?.toString() ?? '';
    final id = data['id']?.toString() ?? data['wr_id']?.toString() ?? '';
    final orderNumber =
        data['order_number']?.toString() ?? data['od_id']?.toString() ?? id;

    switch (type) {
      case 'order':
      case 'delivery':
        if (orderNumber.isNotEmpty) {
          nav.pushNamed(
            '/order-detail',
            arguments: {'orderNumber': orderNumber, 'odId': orderNumber},
          );
        } else {
          nav.pushNamed('/order');
        }
        break;
      case 'health':
        nav.pushNamed('/health');
        break;
      case 'coupon':
        nav.pushNamed('/coupon');
        break;
      case 'event':
        final wrId = int.tryParse(id);
        if (wrId != null && wrId > 0) {
          nav.pushNamed('/event/$wrId');
        } else {
          nav.pushNamed('/event');
        }
        break;
      case 'announcement':
      case 'notice':
        final announcementId = int.tryParse(id);
        if (announcementId != null && announcementId > 0) {
          nav.pushNamed('/announcement/$announcementId');
        } else {
          nav.pushNamed('/announcement');
        }
        break;
      case 'point':
        nav.pushNamed('/point');
        break;
      case 'contact':
      case 'inquiry':
      case 'qna':
        final contactWrId = int.tryParse(id);
        if (contactWrId != null && contactWrId > 0) {
          nav.pushNamed(
            '/qna-detail',
            arguments: {'wrId': contactWrId},
          );
        } else {
          nav.pushNamed('/qna');
        }
        break;
      default:
        nav.pushNamed('/home');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[FCM] subscribe $topic 실패: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[FCM] unsubscribe $topic 실패: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationInboxService.addFromFcm(
    data: Map<String, dynamic>.from(message.data),
    title: message.notification?.title,
    body: message.notification?.body,
  );
}
