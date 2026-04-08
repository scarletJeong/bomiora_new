import 'dart:async';

import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import '../widgets/my_page_common.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';

/// 프로필 설정 화면 (개인정보 수정, 비밀번호 변경)
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  UserModel? _currentUser;
  
  // 회원정보 입력 컨트롤러
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _phone3Controller = TextEditingController();
  final TextEditingController _verificationController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Timer? _verifyTimer;
  int _secondsLeft = 0;
  String? _sentVerificationCode;
  bool _verificationMismatch = false;
  bool _passwordMismatch = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _phone3Controller.dispose();
    _verificationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _verifyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    // 콘솔에 현재 사용자 정보 출력
    print('📱 [프로필 설정] 현재 사용자 정보:');
    print('   - ID: ${user?.id}');
    print('   - 이메일: ${user?.email}');
    print('   - 이름: ${user?.name}');
    print('   - 닉네임: ${user?.nickname}');
    print('   - 전화번호: ${user?.phone}');

    setState(() {
      _currentUser = user;
      _nicknameController.text = user?.nickname ?? '';

      final phone = (user?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.length >= 10) {
        _phone1Controller.text = phone.substring(0, 3);
        _phone2Controller.text = phone.substring(3, phone.length - 4);
        _phone3Controller.text = phone.substring(phone.length - 4);
      } else {
        _phone1Controller.text = '';
        _phone2Controller.text = '';
        _phone3Controller.text = '';
      }
    });
  }
  
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startVerificationTimer() {
    _verifyTimer?.cancel();
    setState(() => _secondsLeft = 180);
    _verifyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _sendVerificationCode() {
    final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    setState(() {
      _sentVerificationCode = code;
      _verificationController.text = '';
      _verificationMismatch = false;
    });
    _startVerificationTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증번호가 발송되었습니다.')),
    );
  }

  void _recomputeVerificationMismatch() {
    final typed = _verificationController.text.trim();
    final sent = _sentVerificationCode;
    final mismatch = sent != null && typed.isNotEmpty && typed.length >= 4 && typed != sent;
    if (mismatch != _verificationMismatch) {
      setState(() => _verificationMismatch = mismatch);
    }
  }

  void _recomputePasswordMismatch() {
    final pw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    final mismatch = confirm.isNotEmpty && pw != confirm;
    if (mismatch != _passwordMismatch) {
      setState(() => _passwordMismatch = mismatch);
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    if (_verificationMismatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호가 일치하지 않습니다.')),
      );
      return;
    }
    if (_passwordMismatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }
    
    try {
      final phone = '${_phone1Controller.text.trim()}${_phone2Controller.text.trim()}${_phone3Controller.text.trim()}';
      final result = await AuthService.updateProfile(
        mbId: _currentUser!.id,
        name: _currentUser!.name,
        nickname: _nicknameController.text.trim(),
        phone: phone,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '프로필이 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 사용자 정보 새로고침
        await _loadCurrentUser();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '프로필 수정에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ 프로필 저장 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 수정 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '개인정보수정'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: _buildPersonalInfoBody(),
      ),
    );
  }

  Widget _buildPersonalInfoBody() {
    // 사용자 정보가 로드되지 않았으면 로딩 표시
    if (_currentUser == null) {
      return const MyPageLoadingIndicator();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(
            name: '${_currentUser!.name} 님',
            email: _currentUser!.email,
            onAddPhoto: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('프로필 사진 변경 기능은 추후 구현 예정입니다')),
              );
            },
          ),
          const SizedBox(height: 20),

          const Text(
            '닉네임',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          _InputBox(
            child: TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '닉네임을 입력해 주세요',
                hintStyle: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            '연락처',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _InputBox(
                        child: TextField(
                          controller: _phone1Controller,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const _Hyphen(),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _InputBox(
                        child: TextField(
                          controller: _phone2Controller,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const _Hyphen(),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _InputBox(
                        child: TextField(
                          controller: _phone3Controller,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _sendVerificationCode,
                  style: MyPageButtonStyles.pinkElevated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text(
                    '변경하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InputBox(
                  borderColor: _verificationMismatch ? const Color(0xFFEF4444) : const Color(0xFFD2D2D2),
                  child: TextField(
                    controller: _verificationController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recomputeVerificationMismatch(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: '인증번호를 입력해 주세요',
                      hintStyle: TextStyle(
                        color: Color(0xFF898686),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _secondsLeft > 0 ? _formatTime(_secondsLeft) : '03:00',
                style: const TextStyle(
                  color: Color(0xFFFF5A8D),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _sendVerificationCode,
                  style: MyPageButtonStyles.pinkElevated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text(
                    '발송',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_verificationMismatch) ...[
            const SizedBox(height: 6),
            const Text(
              '인증번호가 일치하지 않습니다',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),

          const Text(
            '비밀번호 설정',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          _InputBox(
            child: TextField(
              controller: _newPasswordController,
              obscureText: true,
              onChanged: (_) => _recomputePasswordMismatch(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '새 비밀번호를 입력해 주세요.',
                hintStyle: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '*8~16자/문자,숫자,특수문자 모두 혼용',
            style: TextStyle(
              color: Color(0xFF898686),
              fontSize: 10,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),
          _InputBox(
            borderColor: _passwordMismatch ? const Color(0xFFEF4444) : const Color(0xFFD2D2D2),
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              onChanged: (_) => _recomputePasswordMismatch(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '다시 한번 입력해 주세요.',
                hintStyle: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_passwordMismatch) ...[
            const SizedBox(height: 6),
            const Text(
              '비밀번호가 일치하지 않습니다',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: MyPageButtonStyles.pinkElevated(),
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.onAddPhoto,
  });

  final String name;
  final String email;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            MyPageAvatarFrame(
              child: const Icon(Icons.person, color: Color(0xFFFF5A8D), size: 34),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF898686),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 63,
          top: 62.7,
          child: InkWell(
            onTap: onAddPhoto,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: 18,
              height: 18,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Center(
                child: Icon(Icons.add, size: 14, color: Color(0xFFFF5A8D)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hyphen extends StatelessWidget {
  const _Hyphen();

  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 1, color: const Color(0xFFD9D9D9));
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.child,
    this.borderColor = const Color(0xFFD2D2D2),
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

