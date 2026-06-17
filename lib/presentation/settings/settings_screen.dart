import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../health/health_common/widgets/health_app_bar.dart';
import '../common/widgets/confirm_dialog.dart';
import 'notification_center_screen.dart';
import 'policy/screens/terms_of_service_screen.dart';
import 'policy/screens/privacy_policy_screen.dart';
import '../customer_service/screens/contact_list_screen.dart';
import '../../data/services/auth_service.dart';
import '../health/health_common/health_responsive_scale.dart';

/// 설정 화면
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '26.01.0';
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kPink = Color(0xFFFF5A8D);

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '설정',
        centerTitle: false,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 27),
          healthDp(context, 20),
          healthDp(context, 27),
          healthDp(context, 20),
        ),
        children: [
          _buildCard(
            context,
            children: [
              _buildRowItem(
                context,
                title: '알림 설정',
                icon: Icons.notifications_none_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationCenterScreen(),
                  ),
                ),
                isLast: true,
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          _buildCard(
            context,
            children: [
              _buildRowItem(
                context,
                title: '공지사항',
                icon: Icons.campaign_outlined,
                onTap: () => Navigator.pushNamed(context, '/announcement'),
              ),
              _buildRowItem(
                context,
                title: '이벤트',
                icon: Icons.local_activity_outlined,
                onTap: () => Navigator.pushNamed(context, '/event'),
                isLast: true,
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          _buildCard(
            context,
            children: [
              _buildRowItem(
                context,
                title: '서비스 이용약관',
                icon: Icons.description_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TermsOfServiceScreen()),
                ),
              ),
              _buildRowItem(
                context,
                title: '개인정보처리방침',
                icon: Icons.privacy_tip_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                ),
                isLast: true,
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 14)),
          _buildCard(
            context,
            children: [
              _buildRowItem(
                context,
                title: '앱정보',
                icon: Icons.info_outline_rounded,
                onTap: _showAppInfoDialog,
                isLast: false,
                trailing: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 5),
                    vertical: healthDp(context, 5),
                  ),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFF6F3F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        healthDp(context, 20),
                      ),
                    ),
                  ),
                  child: Text(
                    _appVersion,
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              _buildRowItem(
                context,
                title: 'FAQ',
                icon: Icons.help_outline_rounded,
                onTap: () => Navigator.pushNamed(context, '/faq'),
              ),
              _buildRowItem(
                context,
                title: '1:1 문의',
                icon: Icons.support_agent_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactListScreen()),
                ),
              ),
              _buildRowItem(
                context,
                title: '카카오톡 상담',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: _openKakaoChannel,
                isLast: true,
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 24)),
          SizedBox(
            height: healthDp(context, 40),
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _kPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: healthSp(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRowItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isLast = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: healthDp(context, 14),
          horizontal: healthDp(context, 10),
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    width: healthDp(context, 0.5),
                    color: _kBorder,
                  ),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: healthDp(context, 20), color: _kPink),
                SizedBox(width: healthDp(context, 6)),
                Text(
                  title,
                  style: TextStyle(
                    color: _kText,
                    fontSize: healthSp(context, 14),
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.26,
                  ),
                ),
              ],
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: _kMuted,
                  size: healthDp(context, 18),
                ),
          ],
        ),
      ),
    );
  }

  /// 앱 정보 다이얼로그
  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('앱 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '보미오라',
              style: TextStyle(
                fontSize: healthSp(dialogContext, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: healthDp(dialogContext, 5)),
            Text(
              '버전: $_appVersion',
              style: TextStyle(
                fontSize: healthSp(dialogContext, 12),
                color: _kMuted,
              ),
            ),
            SizedBox(height: healthDp(dialogContext, 16)),
            Text(
              '건강한 삶을 위한 스마트한 선택\n보미오라와 함께하세요.',
              style: TextStyle(
                fontSize: healthSp(dialogContext, 14),
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openKakaoChannel() async {
    final uri = Uri.parse('https://pf.kakao.com/_NdxgAG');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 로그아웃 처리
  Future<void> _handleLogout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
    );

    if (confirmed) {
      try {
        await AuthService.logout();

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {}
    }
  }
}
