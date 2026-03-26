import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_footer.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';
import 'profile_settings_screen.dart';
import '../../../customer_service/screens/contact_list_screen.dart';
import 'address_management_screen.dart';
import '../../../shopping/wish/screens/wish_list_screen.dart';
import 'refund_account_screen.dart';
import 'cancel_member_screen.dart';
import '../../healthprofile/screens/health_profile_list_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  UserModel? _currentUser;

  Future<void> _showPasswordConfirmDialog() async {
    if (_currentUser == null) return;

    final controller = TextEditingController();
    bool mismatch = false;
    bool submitting = false;

    Future<void> submit(StateSetter setLocalState) async {
      final pw = controller.text;
      if (pw.isEmpty) {
        setLocalState(() => mismatch = true);
        return;
      }

      setLocalState(() {
        submitting = true;
        mismatch = false;
      });

      final ok = await AuthService.verifyPassword(
        mbId: _currentUser!.id,
        password: pw,
      );

      if (!mounted) return;

      if (!ok) {
        setLocalState(() {
          submitting = false;
          mismatch = true;
        });
        return;
      }

      Navigator.of(context).pop(); // close dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileSettingsScreen(),
        ),
      ).then((_) => _loadCurrentUser());
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 272,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 8.14,
                      offset: Offset(0, 0),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '비밀번호 확인',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '***',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD2D2D2),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.57,
                                letterSpacing: 4.90,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '안전한 정보 변경을 위해,\n비밀번호를 한 번 더 입력해 주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF898686),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.57,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        width: 1,
                                        color: mismatch ? const Color(0xFFEF4444) : const Color(0xFFD2D2D2),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: controller,
                                    obscureText: true,
                                    onChanged: (_) {
                                      if (mismatch) setLocalState(() => mismatch = false);
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: '비밀번호를 입력해 주세요',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF898686),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (mismatch) ...[
                                  const SizedBox(height: 5),
                                  const Text(
                                    '비밀번호가 일치하지 않습니다.',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 50,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF7F7F7),
                              child: InkWell(
                                onTap: submitting ? null : () => Navigator.of(context).pop(),
                                child: const Center(
                                  child: Text(
                                    '취소',
                                    style: TextStyle(
                                      color: Color(0xFF898686),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Gmarket Sans TTF',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Material(
                              color: const Color(0xFFFF5A8D),
                              child: InkWell(
                                onTap: submitting ? null : () => submit(setLocalState),
                                child: Center(
                                  child: Text(
                                    submitting ? '확인 중...' : '확인',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Gmarket Sans TTF',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    
    setState(() {
      _currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // 컨텐츠에 padding 적용
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // 회원 정보 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFFF3787).withOpacity(0.1),
                    child: const Icon(
                      Icons.person,
                      size: 34,
                      color: Color(0xFFFF3787),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.name ?? '로그인이 필요합니다',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentUser != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _currentUser!.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              _showPasswordConfirmDialog();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF3787),
                              side: const BorderSide(color: Color(0xFFFF3787)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '개인정보 수정',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (_currentUser != null) ...[
              // 메뉴 리스트
              _buildMenuItem(
                title: '찜목록',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WishListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                title: '배송지 관리',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressManagementScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                title: '환불계좌 등록',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RefundAccountScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                title: '내 리뷰 활동',
                onTap: () {
                  Navigator.pushNamed(context, '/my_reviews');
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                title: '1:1 문의',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContactListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                title: '건강 프로필 관리',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HealthProfileListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CancelMemberScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '회원탈퇴',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // 로그인 안 된 경우
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3787),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
                ],
              ),
            ),
            
            const SizedBox(height: 300),
            
            // Footer  
            const AppFooter(),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}