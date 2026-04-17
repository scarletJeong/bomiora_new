import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../common/widgets/app_bar.dart';
import '../common/widgets/confirm_dialog.dart';
import 'notification_center_screen.dart';
import 'policy/screens/terms_of_service_screen.dart';
import 'policy/screens/privacy_policy_screen.dart';
import '../customer_service/screens/contact_list_screen.dart';
import '../../data/services/auth_service.dart';

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
        centerTitle: true,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
        children: [
          _buildCard(
            children: [
              _buildRowItem(
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
          const SizedBox(height: 20),
          _buildCard(
            children: [
              _buildRowItem(
                title: '공지사항',
                icon: Icons.campaign_outlined,
                onTap: () => Navigator.pushNamed(context, '/announcement'),
              ),
              _buildRowItem(
                title: '이벤트',
                icon: Icons.local_activity_outlined,
                onTap: () => Navigator.pushNamed(context, '/evnt'),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCard(
            children: [
              _buildRowItem(
                title: '서비스 이용약관',
                icon: Icons.description_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TermsOfServiceScreen()),
                ),
              ),
              _buildRowItem(
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
          const SizedBox(height: 20),
          _buildCard(
            children: [
              _buildRowItem(
                title: '앱정보',
                icon: Icons.info_outline_rounded,
                onTap: _showAppInfoDialog,
                isLast: false,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFF6F3F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    _appVersion,
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              _buildRowItem(
                title: 'FAQ',
                icon: Icons.help_outline_rounded,
                onTap: () => Navigator.pushNamed(context, '/faq'),
              ),
              _buildRowItem(
                title: '1:1 문의',
                icon: Icons.support_agent_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactListScreen()),
                ),
              ),
              _buildRowItem(
                title: '카카오톡 상담',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: _openKakaoChannel,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _kPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.5, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRowItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isLast = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(width: 0.5, color: _kBorder),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: _kMuted),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _kMuted,
                  size: 18,
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
      builder: (context) => AlertDialog(
        title: const Text('앱 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '보미오라',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '버전: $_appVersion',
              style: TextStyle(fontSize: 14, color: _kMuted),
            ),
            const SizedBox(height: 16),
            Text(
              '건강한 삶을 위한 스마트한 선택\n보미오라와 함께하세요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openKakaoChannel() async {
    final uri = Uri.parse('https://pf.kakao.com/_NdxgAG');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오톡 상담 페이지를 열 수 없습니다.')),
      );
    }
  }

  void _showPreparingSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('준비 중인 메뉴입니다.')),
    );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그아웃되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );

          // 로그인 화면으로 이동
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그아웃 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
