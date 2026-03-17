import 'package:flutter/material.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/kakao_auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class SignupScreen extends StatefulWidget {
  final Map<String, dynamic>? certInfo; // 본인인증 정보

  const SignupScreen({
    super.key,
    this.certInfo,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  // 본인인증 정보
  String? _certName;
  String? _certPhone;
  String? _certBirthday;
  String? _certGender; // "M" 또는 "F"

  @override
  void initState() {
    super.initState();
    // 본인인증 정보가 있으면 설정
    if (widget.certInfo != null) {
      _certName = widget.certInfo!['name']?.toString();
      _certPhone = widget.certInfo!['phone']?.toString();
      _certBirthday = widget.certInfo!['birthday']?.toString();
      final sexCode = widget.certInfo!['sex_code']?.toString();
      _certGender = (sexCode == "01") ? "M" : "F";
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // 생년월일 포맷팅 (YYYYMMDD -> YYYY-MM-DD)
  String _formatBirthday(String? birthday) {
    if (birthday == null || birthday.length != 8) return '';
    return '${birthday.substring(0, 4)}-${birthday.substring(4, 6)}-${birthday.substring(6, 8)}';
  }

  // 전화번호 포맷팅 (숫자만 -> 010-1234-5678)
  String _formatPhone(String? phone) {
    if (phone == null) return '';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
    }
    return phone;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 본인인증 정보 확인
    if (_certName == null || _certPhone == null || _certBirthday == null || _certGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('본인인증을 먼저 완료해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthRepository.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _certName!,
        phone: _certPhone,
      );

      if (result['success']) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다. 로그인해주세요.'),
            backgroundColor: Colors.green,
          ),
        );

        // 로그인 화면으로 이동
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        if (!mounted) return;
        final errorMessage = result['error'] ?? '회원가입에 실패했습니다';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ [SIGNUP SCREEN] 예외 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원가입 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 본인인증 정보 표시 (읽기 전용)
              if (_certName != null || _certPhone != null || _certBirthday != null || _certGender != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '본인인증 완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_certName != null)
                        _buildReadOnlyField('이름', _certName!),
                      if (_certPhone != null)
                        _buildReadOnlyField('전화번호', _formatPhone(_certPhone)),
                      if (_certBirthday != null)
                        _buildReadOnlyField('생년월일', _formatBirthday(_certBirthday)),
                      if (_certGender != null)
                        _buildReadOnlyField('성별', _certGender == "M" ? "남성" : "여성"),
                    ],
                  ),
                ),

              // 이메일 입력
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일',
                  hintText: 'example@email.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return '올바른 이메일 형식을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 비밀번호 입력
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  hintText: '8자 이상 입력해주세요',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력해주세요';
                  }
                  if (value.length < 8) {
                    return '비밀번호는 8자 이상이어야 합니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 비밀번호 확인
              TextFormField(
                controller: _passwordConfirmController,
                obscureText: _obscurePasswordConfirm,
                decoration: InputDecoration(
                  labelText: '비밀번호 확인',
                  hintText: '비밀번호를 다시 입력해주세요',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePasswordConfirm = !_obscurePasswordConfirm;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호 확인을 입력해주세요';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 닉네임 입력 (선택)
              TextFormField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: '닉네임 (선택)',
                  hintText: '닉네임을 입력해주세요',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 구분선
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '또는',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 24),

              // 카카오 로그인 버튼
              _buildKakaoLoginButton(),
              const SizedBox(height: 24),

              // 회원가입 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 카카오 로그인 버튼
  Widget _buildKakaoLoginButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleKakaoLogin,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: Colors.grey[300]!),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildKakaoIcon(),
          const SizedBox(width: 12),
          const Text(
            '카카오로 시작하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 카카오 아이콘
  Widget _buildKakaoIcon() {
    try {
      return Image.asset(
        'assets/img/kakao_login_on.png',
        width: 24,
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: Colors.black87,
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE500),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          size: 16,
          color: Colors.black87,
        ),
      );
    }
  }

  // 카카오 로그인 처리
  Future<void> _handleKakaoLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final kakaoResult = await KakaoAuthService.login();

      if (!kakaoResult['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kakaoResult['error'] ?? '카카오 로그인에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final kakaoData = kakaoResult['data'];
      final kakaoId = kakaoData['kakaoId']?.toString() ?? '';
      final email = kakaoData['email']?.toString();
      final nickname = kakaoData['nickname']?.toString();

      if (kakaoId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카카오 로그인 정보를 가져올 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 서버에 카카오 로그인 요청
      final result = await AuthRepository.loginWithKakao(
        kakaoId: kakaoId,
        email: email,
        nickname: nickname,
        profileImageUrl: kakaoData['profileImageUrl']?.toString(),
        accessToken: kakaoData['accessToken']?.toString(),
      );

      if (result['success']) {
        final resultData = result['data'];
        if (resultData is! Map) {
          throw const FormatException('카카오 로그인 응답 형식이 올바르지 않습니다.');
        }
        final userData = NodeValueParser.normalizeMap(
          Map<String, dynamic>.from(resultData),
        );
        final userRaw = userData['user'];
        final userJson = NodeValueParser.normalizeMap(
          userRaw is Map
              ? Map<String, dynamic>.from(userRaw)
              : Map<String, dynamic>.from(userData),
        );
        
        final userId =
            NodeValueParser.asString(userJson['mb_id']) ??
            NodeValueParser.asString(userJson['id']) ??
            '';
        userJson['id'] = userId;

        final user = UserModel.fromJson(userJson);
        final token = NodeValueParser.asString(userData['token']);

        await AuthService.saveLoginData(user: user, token: token);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name}님, 환영합니다!')),
        );

        Future.microtask(() {
          if (!mounted) return;
          try {
            Navigator.of(context).pushReplacementNamed('/home');
          } catch (e) {
            print('❌ [KAKAO LOGIN] 네비게이션 오류: $e');
          }
        });
      } else {
        if (!mounted) return;
        final errorMessage = result['error'] ?? '카카오 로그인에 실패했습니다';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ [KAKAO LOGIN] 예외 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('카카오 로그인 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
