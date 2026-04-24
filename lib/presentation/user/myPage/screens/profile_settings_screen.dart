import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import '../widgets/my_page_common.dart';
import '../../../../data/repositories/auth/auth_repository.dart';
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
  bool _passwordMismatch = false;

  static const String _contactOtpPurpose = 'profile_phone';
  String _originalPhoneDigits = '';
  String? _contactOtpToken;
  bool _contactPhoneVerified = true;
  bool _contactOtpSending = false;
  bool _contactOtpVerifying = false;
  String? _contactOtpErrorText;

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

    final phone = (user?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _currentUser = user;
      _nicknameController.text = user?.nickname ?? '';

      if (phone.length >= 10) {
        _phone1Controller.text = phone.substring(0, 3);
        _phone2Controller.text = phone.substring(3, phone.length - 4);
        _phone3Controller.text = phone.substring(phone.length - 4);
      } else {
        _phone1Controller.text = '';
        _phone2Controller.text = '';
        _phone3Controller.text = '';
      }
      _originalPhoneDigits = phone;
      _contactPhoneVerified = true;
      _contactOtpToken = null;
      _contactOtpErrorText = null;
      _verificationController.clear();
      _secondsLeft = 0;
      _verifyTimer?.cancel();
    });
  }
  
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startVerificationCountdown(int initialSeconds) {
    _verifyTimer?.cancel();
    setState(() => _secondsLeft = initialSeconds);
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

  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  String get _enteredPhoneDigits =>
      '${_phone1Controller.text.trim()}${_phone2Controller.text.trim()}${_phone3Controller.text.trim()}';

  void _onPhoneDigitsChanged() {
    final entered = _enteredPhoneDigits;
    if (entered != _originalPhoneDigits) {
      if (_contactPhoneVerified) {
        setState(() {
          _contactPhoneVerified = false;
          _contactOtpToken = null;
          _contactOtpErrorText = null;
        });
      }
    } else {
      setState(() {
        _contactPhoneVerified = true;
        _contactOtpErrorText = null;
      });
    }
  }

  Future<void> _requestContactChangeOtp() async {
    if (_currentUser == null) return;
    final name = _currentUser!.name.trim();
    final phoneDigits = _digitsOnly(_currentUser!.phone ?? '');
    if (name.isEmpty || phoneDigits.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록된 연락처로 인증번호를 보낼 수 없습니다. 고객센터로 문의해 주세요.'),
        ),
      );
      return;
    }
    final phoneApi = phoneDigits.length == 11
        ? '${phoneDigits.substring(0, 3)}-${phoneDigits.substring(3, 7)}-${phoneDigits.substring(7)}'
        : _currentUser!.phone!.trim();

    setState(() {
      _contactOtpSending = true;
      _contactOtpErrorText = null;
    });
    final send = await AuthRepository.otpSend(
      purpose: _contactOtpPurpose,
      name: name,
      phone: phoneApi,
    );
    if (!mounted) return;
    setState(() => _contactOtpSending = false);

    if (send['success'] != true) {
      setState(() {
        _contactOtpErrorText =
            send['error']?.toString() ?? '인증번호 발송에 실패했습니다.';
      });
      return;
    }

    final token = send['otpToken']?.toString();
    if (token == null || token.isEmpty) {
      setState(() {
        _contactOtpErrorText = '인증 응답이 올바르지 않습니다. (otpToken 누락)';
      });
      return;
    }

    final ttl = int.tryParse(send['ttlSeconds']?.toString() ?? '');
    final ttlSeconds = (ttl != null && ttl > 0 && ttl <= 600) ? ttl : 180;

    setState(() {
      _contactOtpToken = token;
      _verificationController.clear();
      _contactOtpErrorText = null;
    });
    _startVerificationCountdown(ttlSeconds);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증번호가 발송되었습니다.')),
    );
  }

  Future<void> _confirmContactChangeOtp() async {
    final token = _contactOtpToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 [변경하기]로 인증번호를 요청해 주세요.')),
      );
      return;
    }
    final code = _verificationController.text.trim();
    if (code.length < 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호를 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _contactOtpVerifying = true;
      _contactOtpErrorText = null;
    });
    final verify = await AuthRepository.otpVerify(
      otpToken: token,
      code: code,
      purpose: _contactOtpPurpose,
    );
    if (!mounted) return;
    setState(() => _contactOtpVerifying = false);

    if (verify['success'] != true) {
      setState(() {
        _contactOtpErrorText =
            verify['error']?.toString() ?? '인증에 실패했습니다.';
      });
      return;
    }

    setState(() {
      _contactPhoneVerified = true;
      _contactOtpToken = null;
      _secondsLeft = 0;
      _contactOtpErrorText = null;
    });
    _verifyTimer?.cancel();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증이 완료되었습니다. 연락처를 수정한 뒤 저장해 주세요.')),
    );
  }

  void _recomputePasswordMismatch() {
    final pw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    final mismatch = confirm.isNotEmpty && pw != confirm;
    if (mismatch != _passwordMismatch) {
      setState(() => _passwordMismatch = mismatch);
    }
  }

  bool _isValidPassword(String pw) {
    final t = pw.trim();
    if (t.length < 8 || t.length > 16) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(t);
    final hasDigit = RegExp(r'[0-9]').hasMatch(t);
    final hasSpecial =
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]~`+=;]').hasMatch(t);
    return hasLetter && hasDigit && hasSpecial;
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    if (_passwordMismatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }
    
    try {
      final phone = _enteredPhoneDigits;
      if (phone != _originalPhoneDigits && !_contactPhoneVerified) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('연락처를 변경하려면 [변경하기]로 인증 후 [확인]까지 완료해 주세요.'),
          ),
        );
        return;
      }
      final result = await AuthService.updateProfile(
        mbId: _currentUser!.id,
        name: _currentUser!.name,
        nickname: _nicknameController.text.trim(),
        phone: phone,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        final newPw = _newPasswordController.text.trim();
        final confirmPw = _confirmPasswordController.text.trim();

        if (newPw.isNotEmpty || confirmPw.isNotEmpty) {
          if (newPw.isEmpty || confirmPw.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('새 비밀번호/확인을 모두 입력해 주세요.')),
            );
            return;
          }
          if (!_isValidPassword(newPw)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('비밀번호는 8~16자이며 문자/숫자/특수문자를 모두 포함해야 합니다.'),
              ),
            );
            return;
          }
          if (newPw != confirmPw) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
            );
            return;
          }

          final pwResult = await AuthService.changePassword(
            mbId: _currentUser!.id,
            newPassword: newPw,
          );
          if (!mounted) return;
          if (pwResult['success'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  pwResult['message']?.toString() ?? '비밀번호 변경에 실패했습니다.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          _newPasswordController.clear();
          _confirmPasswordController.clear();
        }

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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 3,
                          textAlign: TextAlign.center,
                          onChanged: (_) => _onPhoneDigitsChanged(),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          onChanged: (_) => _onPhoneDigitsChanged(),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          onChanged: (_) => _onPhoneDigitsChanged(),
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
                  onPressed:
                      _contactOtpSending ? null : _requestContactChangeOtp,
                  style: MyPageButtonStyles.pinkElevated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(
                    _contactOtpSending ? '발송 중…' : '변경하기',
                    style: const TextStyle(
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
                  borderColor: _contactOtpErrorText != null
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFD2D2D2),
                  child: TextField(
                    controller: _verificationController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) {
                      if (_contactOtpErrorText != null) {
                        setState(() => _contactOtpErrorText = null);
                      }
                    },
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
                _secondsLeft > 0 ? _formatTime(_secondsLeft) : '--:--',
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
                  onPressed: (_contactOtpVerifying || _contactOtpSending)
                      ? null
                      : _confirmContactChangeOtp,
                  style: MyPageButtonStyles.pinkElevated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(
                    _contactOtpVerifying ? '확인 중…' : '확인',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_contactOtpErrorText != null && _contactOtpErrorText!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _contactOtpErrorText!,
              style: const TextStyle(
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

