import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../../core/utils/snackbar_utils.dart';
// 조건부 임포트: 웹과 모바일에서 다른 FCM 서비스 사용
// TODO: 웹 개발 완료 후 주석 해제
// import '../../data/services/fcm_service_stub.dart'
//   if (dart.library.io) '../../data/services/fcm_service.dart';

/// 알림 설정 화면
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _orderNotification = true; // 주문/배송 알림
  bool _healthNotification = true; // 건강 알림
  bool _eventNotification = true; // 이벤트/쿠폰 알림
  bool _marketingNotification = true; // 마케팅 알림
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 저장된 알림 설정 불러오기
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _orderNotification = prefs.getBool('notification_order') ?? true;
        _healthNotification = prefs.getBool('notification_health') ?? true;
        _eventNotification = prefs.getBool('notification_event') ?? true;
        _marketingNotification = prefs.getBool('notification_marketing') ?? true;
      });
    } catch (e) {
      print('❌ 알림 설정 불러오기 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 알림 설정 저장
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_order', _orderNotification);
      await prefs.setBool('notification_health', _healthNotification);
      await prefs.setBool('notification_event', _eventNotification);
      await prefs.setBool('notification_marketing', _marketingNotification);

      // FCM 토픽 구독/해제 (TODO: 웹 개발 완료 후 주석 해제)
      // final fcmService = FCMService();
      // if (_orderNotification) {
      //   await fcmService.subscribeToTopic('order');
      //   await fcmService.subscribeToTopic('delivery');
      // } else {
      //   await fcmService.unsubscribeFromTopic('order');
      //   await fcmService.unsubscribeFromTopic('delivery');
      // }

      // if (_healthNotification) {
      //   await fcmService.subscribeToTopic('health');
      // } else {
      //   await fcmService.unsubscribeFromTopic('health');
      // }

      // if (_eventNotification) {
      //   await fcmService.subscribeToTopic('event');
      //   await fcmService.subscribeToTopic('coupon');
      // } else {
      //   await fcmService.unsubscribeFromTopic('event');
      //   await fcmService.unsubscribeFromTopic('coupon');
      // }

      // if (_marketingNotification) {
      //   await fcmService.subscribeToTopic('marketing');
      // } else {
      //   await fcmService.unsubscribeFromTopic('marketing');
      // }

      if (mounted) {
        SnackBarUtils.showSuccess(context, '알림 설정이 저장되었습니다.');
      }
    } catch (e) {
      print('❌ 알림 설정 저장 실패: $e');
      if (mounted) {
        SnackBarUtils.showError(context, '알림 설정 저장에 실패했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '알림 설정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF3787),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 주문/배송 알림
                _buildNotificationTile(
                  title: '주문/배송 알림',
                  subtitle: '주문 상태 변경, 배송 시작 등',
                  value: _orderNotification,
                  onChanged: (value) {
                    setState(() => _orderNotification = value);
                    _saveSettings();
                  },
                ),
                const Divider(),

                // 건강 알림
                _buildNotificationTile(
                  title: '건강 알림',
                  subtitle: '체중 기록 리마인더, 건강 프로필 작성',
                  value: _healthNotification,
                  onChanged: (value) {
                    setState(() => _healthNotification = value);
                    _saveSettings();
                  },
                ),
                const Divider(),

                // 이벤트/쿠폰 알림
                _buildNotificationTile(
                  title: '이벤트/쿠폰 알림',
                  subtitle: '이벤트 시작, 쿠폰 발급',
                  value: _eventNotification,
                  onChanged: (value) {
                    setState(() => _eventNotification = value);
                    _saveSettings();
                  },
                ),
                const Divider(),

                // 마케팅 알림
                _buildNotificationTile(
                  title: '마케팅 알림',
                  subtitle: '신상품, 할인 정보 등',
                  value: _marketingNotification,
                  onChanged: (value) {
                    setState(() => _marketingNotification = value);
                    _saveSettings();
                  },
                ),
                const Divider(),

                const SizedBox(height: 20),

                // FCM 토큰 정보 (개발자용)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FCM 토큰 (개발자용)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String?>(
                        future: _getFCMToken(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('토큰 불러오는 중...');
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Text('토큰을 불러올 수 없습니다.');
                          }
                          return SelectableText(
                            snapshot.data!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 배지 초기화 버튼
                ElevatedButton.icon(
                  onPressed: () async {
                    // TODO: 웹 개발 완료 후 주석 해제
                    // await FCMService().clearBadge();
                    if (mounted) {
                      SnackBarUtils.showInfo(context, '알림 배지 초기화 기능은 임시 비활성화되었습니다.');
                    }
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('알림 배지 초기화'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF4CAF50),
    );
  }

  Future<String?> _getFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    // TODO: 웹 개발 완료 후 주석 해제
    // return prefs.getString('fcm_token') ?? FCMService().fcmToken;
    return prefs.getString('fcm_token');
  }
}

