import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../common/widgets/centered_empty_state.dart';
import '../health/health_common/widgets/health_app_bar.dart';
import '../health/health_common/health_responsive_scale.dart';
import '../../data/models/notification/notification_settings_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/fcm_service_stub.dart'
    if (dart.library.io) '../../data/services/fcm_service.dart';
import '../../data/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const String _font = 'Gmarket Sans TTF';
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kText = Color(0xFF1A1A1E);
  static const Color _kPink = Color(0xFFFF5A8D);

  bool _loading = true;
  bool _saving = false;
  bool _requiresLogin = false;

  /// mb_notif_order — UI 미노출, 기존 값 유지
  bool _orderAgree = false;

  /// mb_notif_marketing — 마케팅 정보 수신 동의
  bool _marketingAgree = false;

  /// mb_notif_app_push — 야간 알림
  bool _nightAgree = false;

  /// mb_notif_sms — UI 미노출, 마케팅과 동기화
  bool _smsAgree = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _loading = false;
      });
      return;
    }

    final settings = await NotificationService.loadSettings();
    if (!mounted) return;
    setState(() {
      _orderAgree = settings.orderAgree;
      _marketingAgree = settings.marketingAgree;
      _nightAgree = settings.appPushAgree;
      _smsAgree = settings.smsAgree;
      _loading = false;
    });
  }

  NotificationSettingsModel get _currentSettings => NotificationSettingsModel(
        orderAgree: _orderAgree,
        marketingAgree: _marketingAgree,
        appPushAgree: _nightAgree,
        smsAgree: _smsAgree,
      );

  Future<void> _persist() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await NotificationService.saveSettings(_currentSettings);
    await FCMService().syncTopicsFromSettings();
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 설정 저장에 실패했습니다.')),
      );
    }
  }

  Future<void> _onMarketingChanged(bool value) async {
    setState(() {
      _marketingAgree = value;
      // 마케팅 채널(SMS)도 함께 맞춤
      _smsAgree = value;
    });
    await _persist();
  }

  Future<void> _onNightChanged(bool value) async {
    setState(() => _nightAgree = value);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(
          title: '알림 설정',
          centerTitle: false,
        ),
        child: _loading
            ? Center(
                child: SizedBox(
                  width: healthDp(context, 32),
                  height: healthDp(context, 32),
                  child: const CircularProgressIndicator(color: _kPink),
                ),
              )
            : _requiresLogin
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight,
                        child: CenteredEmptyState(
                          fillAvailable: true,
                          iconWidget: CenteredEmptyState.assetIcon(
                            context,
                            AppAssets.emptySettingIcon,
                          ),
                          message: '로그인 후 이용 가능합니다.',
                          trailing: CenteredEmptyState.loginButtonTrailing(
                            context,
                          ),
                        ),
                      );
                    },
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      healthDp(context, 27),
                      healthDp(context, 20),
                      healthDp(context, 27),
                      healthDp(context, 48),
                    ),
                    children: [
                      _buildSettingCard(
                        context,
                        title: '마케팅 정보 수신 동의',
                        description:
                            '이벤트, 할인 쿠폰 등 혜택에 대한 알림 메시지를받습니다. ',
                        value: _marketingAgree,
                        onChanged: _saving ? null : _onMarketingChanged,
                      ),
                      SizedBox(height: healthDp(context, 20)),
                      Text(
                        '회원정보, 구매정보 및 서비스 주요 정책 관련 내용은 \n수신동의 여부와 관계없이 발송됩니다.',
                        style: TextStyle(
                          color: _kText,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w300,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 20)),
                      _buildSettingCard(
                        context,
                        title: '야간 알림',
                        description: '오후 9시 - 익일 오전 8시에도 알림 수신을 받으실 수 있어요.',
                        value: _nightAgree,
                        onChanged: _saving ? null : _onNightChanged,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final radius = healthDp(context, 10);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorder,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(width: 0.5, color: Color(0x7FD2D2D2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: _kText,
                      fontSize: healthSp(context, 14),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: healthSp(context, -1.26),
                    ),
                  ),
                ),
                _TinyToggle(
                  value: value,
                  onChanged: onChanged ?? (_) {},
                  activeColor: _kPink,
                  inactiveColor: _kBorder,
                  enabled: onChanged != null,
                ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            description,
            style: TextStyle(
              color: _kText,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
              letterSpacing: healthSp(context, -1.08),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyToggle extends StatelessWidget {
  const _TinyToggle({
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.inactiveColor,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final knob = healthDp(context, 12);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: healthDp(context, 30),
          padding: EdgeInsets.all(healthDp(context, 2)),
          decoration: ShapeDecoration(
            color: value ? activeColor : inactiveColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 12)),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                value ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: const ShapeDecoration(
                  color: Colors.white,
                  shape: StadiumBorder(),
                ),
                child: SizedBox(width: knob, height: knob),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
