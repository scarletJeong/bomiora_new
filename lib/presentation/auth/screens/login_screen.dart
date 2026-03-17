import 'package:flutter/material.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/kakao_auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 로고
              Image.asset(
                'assets/images/bomiora-logo.png',
                height: 80,
              ),
              const SizedBox(height: 32),
              
              // 제목
              const Text(
                '보미오라 로그인',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              const Text(
                '다이어트 쇼핑몰에 오신 것을 환영합니다',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // 이메일 입력
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일',
                  hintText: 'test@example.com',
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
                  hintText: 'password123',
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
                  
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              // 로그인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
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
                        '로그인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              
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
              
              // 아이디/비밀번호 찾기 | 회원가입 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('아이디/비밀번호 찾기 기능은 준비 중입니다')),
                      );
                    },
                    child: const Text(
                      '아이디/비밀번호 찾기',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Text(
                    '  |  ',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/kcp-cert');
                    },
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 실제 로그인 API 호출
      final result = await AuthRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        final resultData = result['data'];
        if (resultData is! Map) {
          throw const FormatException('로그인 응답 형식이 올바르지 않습니다.');
        }
        final userData = NodeValueParser.normalizeMap(
          Map<String, dynamic>.from(resultData as Map),
        );
        
        print('🔍 [LOGIN DEBUG] 전체 응답 데이터: $userData');
        
        // mb_id를 id로 매핑
        final userRaw = userData['user'];
        final userJson = NodeValueParser.normalizeMap(
          userRaw is Map
              ? Map<String, dynamic>.from(userRaw)
              : Map<String, dynamic>.from(userData),
        );
        
        print('👤 [LOGIN DEBUG] 원본 user 데이터: $userJson');
        print('📋 [LOGIN DEBUG] id (mb_no): ${userJson['id']}');
        print('📋 [LOGIN DEBUG] mbId: ${userJson['mbId']}');
        print('📋 [LOGIN DEBUG] mb_no: ${userJson['mb_no']}');
        print('📋 [LOGIN DEBUG] mb_id: ${userJson['mb_id']}');
        print('📋 [LOGIN DEBUG] email: ${userJson['email']}');
        print('📋 [LOGIN DEBUG] name: ${userJson['name']}');
        
        final userId =
            NodeValueParser.asString(userJson['mb_id']) ??
            NodeValueParser.asString(userJson['id']) ??
            '';
        userJson['id'] = userId;
        // 비밀번호 저장
        userJson['password'] = _passwordController.text;
        
        print('✅ [LOGIN DEBUG] 최종 매핑된 id: $userId');
        
        final user = UserModel.fromJson(userJson);
        
        print('💾 [LOGIN DEBUG] UserModel 생성 완료:');
        print('   - id: ${user.id}');
        print('   - email: ${user.email}');
        print('   - name: ${user.name}');
        print('   - phone: ${user.phone}');
        
        final token = NodeValueParser.asString(userData['token']); // token이 없으면 null이 됨

        await AuthService.saveLoginData(user: user, token: token); // token을 String?으로 전달

        if (!mounted) return;
        
        // SnackBar 표시
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name}님, 환영합니다!')),
          );
        } catch (e) {
          print('⚠️ [LOGIN] SnackBar 표시 오류: $e');
        }
        
        // 다음 마이크로태스크에서 네비게이션 실행 (더 안전함)
        Future.microtask(() {
          if (!mounted) return;
          try {
            // context를 다시 가져와서 사용
            final navigator = Navigator.of(context);
            navigator.pushReplacementNamed('/home');
          } catch (e) {
            print('❌ [LOGIN] 네비게이션 오류: $e');
            // 실패 시 홈으로 이동 시도
            if (mounted) {
              try {
                Navigator.of(context).pushReplacementNamed('/home');
              } catch (e2) {
                print('❌ [LOGIN] 홈 네비게이션도 실패: $e2');
              }
            }
          }
        });
      } else {
        if (mounted) {
          final errorMessage = result['error']?.toString() ?? '로그인에 실패했습니다';
          print('❌ [LOGIN SCREEN] 로그인 실패: $errorMessage');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ [LOGIN SCREEN] 예외 발생: $e');
      print('❌ [LOGIN SCREEN] 스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          // 카카오 로그인 이미지가 있으면 사용, 없으면 아이콘 사용
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

  // 카카오 아이콘 (이미지가 있으면 이미지, 없으면 기본 아이콘)
  Widget _buildKakaoIcon() {
    // 실제 에셋 경로: assets/img/kakao_login_on.png
    try {
      return Image.asset(
        'assets/img/kakao_login_on.png',
        width: 24,
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          // 이미지가 없으면 기본 아이콘 사용
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500), // 카카오 노란색
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
      // 이미지 로드 실패 시 기본 아이콘
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE500), // 카카오 노란색
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
      // 카카오 로그인
      final kakaoResult = await KakaoAuthService.login();

      if (!kakaoResult['success']) {
        if (!mounted) return;
        
        // 웹 환경에서 서버 인증이 필요한 경우
        if (kakaoResult['needsServerAuth'] == true) {
          // 서버 API를 통해 카카오 로그인 처리
          // 서버에서 카카오 OAuth를 처리하도록 요청
          // 여기서는 직접 서버 API를 호출하는 방식으로 처리
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('웹 환경에서는 서버를 통해 카카오 로그인을 처리합니다. 서버 API를 구현해주세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
        
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
          Map<String, dynamic>.from(resultData as Map),
        );
        final userRaw = userData['user'];
        final userJson = NodeValueParser.normalizeMap(
          userRaw is Map
              ? Map<String, dynamic>.from(userRaw)
              : Map<String, dynamic>.from(userData),
        );
        
        // mb_id를 id로 매핑
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
        final errorMessage = result['error']?.toString() ?? '카카오 로그인에 실패했습니다';
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