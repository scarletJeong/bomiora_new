import 'package:flutter/material.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../common/widgets/app_bar.dart';

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

  bool _orderAgree = false;
  bool _marketingAgree = false;
  bool _appPushAgree = false;
  bool _smsAgree = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(
          title: '알림 설정',
          centerTitle: false,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
          children: [
            const SizedBox(height: 10),
            _buildSingleOptionCard(
              title: '주문 정보 알림 수신동의',
              value: _orderAgree,
              onChanged: (value) => setState(() => _orderAgree = value),
            ),
            const SizedBox(height: 10),
            _buildMarketingCard(),
            const SizedBox(height: 24),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(
                    fontSize: 16,
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

  Widget _buildSingleOptionCard({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.5, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: _buildOptionRow(
        title: title,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMarketingCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.5, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        children: [
          _buildOptionRow(
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
            isTopLevel: true,
          ),
          if (_marketingAgree) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0x7FD2D2D2)),
            const SizedBox(height: 10),
            _buildOptionRow(
              title: '앱 푸시 수신',
              value: _appPushAgree,
              onChanged: (value) => setState(() => _appPushAgree = value),
              indent: 20,
            ),
            const SizedBox(height: 10),
            _buildOptionRow(
              title: 'SMS 수신',
              value: _smsAgree,
              onChanged: (value) => setState(() => _smsAgree = value),
              indent: 20,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isTopLevel = false,
    double indent = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kText,
              fontSize: 16,
              fontFamily: _font,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.44,
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

  void _saveSettings() {
    // 스낵바 제거: 쇼핑/인증 외 화면 정책
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 30,
        padding: const EdgeInsets.all(2),
        decoration: ShapeDecoration(
          color: value ? activeColor : inactiveColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              value ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: const [
            DecoratedBox(
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: StadiumBorder(),
              ),
              child: SizedBox(width: 12, height: 12),
            ),
          ],
        ),
      ),
    );
  }
}
