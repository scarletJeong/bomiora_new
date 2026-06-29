import 'package:flutter/material.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../health/health_common/widgets/health_app_bar.dart';
import '../health/health_common/health_responsive_scale.dart';
import '../../data/models/notification/notification_settings_model.dart';
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
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kPink = Color(0xFFFF5A8D);

  bool _loading = true;
  bool _saving = false;
  bool _orderAgree = false;
  bool _marketingAgree = false;
  bool _appPushAgree = false;
  bool _smsAgree = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await NotificationService.loadSettings();
    if (!mounted) return;
    setState(() {
      _orderAgree = settings.orderAgree;
      _marketingAgree = settings.marketingAgree;
      _appPushAgree = settings.appPushAgree;
      _smsAgree = settings.smsAgree;
      _loading = false;
    });
  }

  NotificationSettingsModel get _currentSettings => NotificationSettingsModel(
        orderAgree: _orderAgree,
        marketingAgree: _marketingAgree,
        appPushAgree: _appPushAgree,
        smsAgree: _smsAgree,
      );

  Future<void> _saveSettings() async {
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
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('알림 설정이 저장되었습니다.')),
    );
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
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
          ),
          children: [
            //SizedBox(height: healthDp(context, 10)),
            _buildSingleOptionCard(
              context,
              title: '주문 정보 알림 수신동의',
              value: _orderAgree,
              onChanged: (value) => setState(() => _orderAgree = value),
            ),
            SizedBox(height: healthDp(context, 14)),
            _buildMarketingCard(context),
            SizedBox(height: healthDp(context, 20)),
            SizedBox(
              height: healthDp(context, 40),
              child: ElevatedButton(
                onPressed: _saving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  _saving ? '저장 중…' : '저장',
                  style: TextStyle(
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleOptionCard(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: healthDp(context, 56),
      padding: EdgeInsets.symmetric(
        vertical: healthDp(context, 10),
        horizontal: healthDp(context, 10),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: _buildOptionRow(
        context,
        title: title,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMarketingConsentRow(BuildContext context) {
    return _buildOptionRow(
      context,
      title: '마케팅 정보 수신 동의',
      value: _marketingAgree,
      onChanged: (value) {
        setState(() {
          _marketingAgree = value;
          if (value) {
            _appPushAgree = true;
            _smsAgree = true;
          } else {
            _appPushAgree = false;
            _smsAgree = false;
          }
        });
      },
    );
  }

  Widget _buildMarketingCard(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: healthDp(context, 56),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: healthDp(context, 10),
                horizontal: healthDp(context, 10),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildMarketingConsentRow(context),
              ),
            ),
          ),
          if (_marketingAgree) ...[
            SizedBox(height: healthDp(context, 0)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              child: Container(
                height: healthDp(context, 1),
                color: const Color(0x7FD2D2D2),
              ),
            ),
            SizedBox(height: healthDp(context, 10)),
            SizedBox(
              height: healthDp(context, 36),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 10),
                ),
                child: _buildOptionRow(
                  context,
                  title: '앱 푸시 수신',
                  value: _appPushAgree,
                  onChanged: (value) => setState(() => _appPushAgree = value),
                  indent: healthDp(context, 20),
                ),
              ),
            ),
            SizedBox(
              height: healthDp(context, 36),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: healthDp(context, 10),
                  horizontal: healthDp(context, 10),
                ),
                child: _buildOptionRow(
                  context,
                  title: 'SMS 수신',
                  value: _smsAgree,
                  onChanged: (value) => setState(() => _smsAgree = value),
                  indent: healthDp(context, 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    double indent = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _kText,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
              letterSpacing: healthSp(context, -1.26),
            ),
          ),
          _TinyToggle(
            value: value,
            onChanged: onChanged,
            activeColor: _kPink,
            inactiveColor: const Color(0xFFD2D2D2),
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
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final knob = healthDp(context, 12);
    return InkWell(
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      onTap: () => onChanged(!value),
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
    );
  }
}
