import 'package:flutter/material.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/kakao_auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import 'signup_screen.dart';

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
  bool _autoLogin = false;
  String? _loginErrorText;
  String? _returnTo;
  bool _didApplyPrefillEmail = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['returnTo']?.toString();
      if (v != null && v.isNotEmpty && v != '/login') {
        _returnTo = v;
      }
      final prefill = args['prefillEmail']?.toString().trim();
      if (!_didApplyPrefillEmail &&
          prefill != null &&
          prefill.isNotEmpty &&
          _emailController.text.trim().isEmpty) {
        _emailController.text = prefill;
        _didApplyPrefillEmail = true;
      }
    }
  }

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
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 40,
            ),
            child: Center(
              child: Form(
                key: _formKey,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(37),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              AppAssets.bomioraPinkLogo,
                              height: 22,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 48),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputField(
                                  controller: _emailController,
                                  hintText: '이메일',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '이메일을 입력해주세요';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                _buildPasswordField(),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeInOut,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_loginErrorText != null) ...[
                                        const SizedBox(height: 14),
                                        Text(
                                          _loginErrorText!,
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 12,
                                            fontFamily: 'Gmarket Sans TTF',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: _loginErrorText != null ? 14 : 10),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: _isLoading
                                      ? null
                                      : () => setState(() => _autoLogin = !_autoLogin),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 20,
                                        height: 20,
                                        decoration: ShapeDecoration(
                                          color: _autoLogin
                                              ? const Color(0xFFFF5A8D)
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                              width: 0.5,
                                              color: _autoLogin
                                                  ? const Color(0xFFFF5A8D)
                                                  : const Color(0xFF898383),
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: _autoLogin
                                            ? const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '자동로그인',
                                        style: TextStyle(
                                          color: Color(0xFF898383),
                                          fontSize: 12,
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildLoginButton(),
                                const SizedBox(height: 20),
                                _buildLinkRow(),
                              ],
                            ),
                            const SizedBox(height: 48),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(
                                  backgroundColor: const Color(0xFF03C75A),
                                  imagePath: AppAssets.loginNaver,
                                  onTap: null,
                                  imageSize: 42,
                                ),
                                const SizedBox(width: 10),
                                _buildSocialButton(
                                  backgroundColor: const Color(0xFFFFE812),
                                  imagePath: AppAssets.loginKakao,
                                  onTap: _isLoading ? null : _handleKakaoLogin,
                                  imageSize: 42,
                                ),
                                const SizedBox(width: 10),
                                _buildSocialButton(
                                  backgroundColor: Colors.white,
                                  imagePath: AppAssets.loginGoogle,
                                  onTap: null,
                                  imageSize: 42,
                                  imageScale: 1.15,
                                ),
                                const SizedBox(width: 10),
                                _buildSocialButton(
                                  backgroundColor: Colors.black,
                                  imagePath: AppAssets.loginApple,
                                  onTap: null,
                                  imageSize: 42,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
      _loginErrorText = null;
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
          Map<String, dynamic>.from(resultData),
        );

        // mb_id를 id로 매핑
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
        // 비밀번호 저장
        userJson['password'] = _passwordController.text;

        final user = UserModel.fromJson(userJson);

        final token = NodeValueParser.asString(userData['token']); // token이 없으면 null이 됨

        await AuthService.saveLoginData(user: user, token: token); // token을 String?으로 전달

        if (!mounted) return;
        
        // 다음 마이크로태스크에서 네비게이션 실행 (더 안전함)
        Future.microtask(() {
          if (!mounted) return;
          try {
            // context를 다시 가져와서 사용
            final navigator = Navigator.of(context);
            navigator.pushReplacementNamed(_returnTo ?? '/home');
          } catch (e) {
            // 실패 시 홈으로 이동 시도
            if (mounted) {
              try {
                Navigator.of(context).pushReplacementNamed(_returnTo ?? '/home');
              } catch (_) {}
            }
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _loginErrorText = '아이디 혹은 비밀번호가 일치하지 않습니다.';
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: (_) {
          if (_loginErrorText != null) {
            setState(() => _loginErrorText = null);
          }
        },
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0x7F707070),
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFFF5A8D), width: 1.2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '비밀번호를 입력해주세요';
          }
          return null;
        },
        onChanged: (_) {
          if (_loginErrorText != null) {
            setState(() => _loginErrorText = null);
          }
        },
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '비밀번호',
          hintStyle: const TextStyle(
            color: Color(0x7F707070),
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFFF5A8D), width: 1.2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF898383),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A8D),
          disabledBackgroundColor: const Color(0xFFFF5A8D).withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: const Color(0x3F000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
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
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildLinkRow() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/find-account'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text(
              '아이디/비밀번호 찾기',
              style: TextStyle(
                color: Color(0xFF898383),
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 15,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFF898383),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const SignupScreen(),
              ),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text(
              '회원가입',
              style: TextStyle(
                color: Color(0xFF898383),
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required Color backgroundColor,
    required String imagePath,
    required VoidCallback? onTap,
    Color? borderColor,
    double imageSize = 24,
    double imageScale = 1.0,
    EdgeInsets imagePadding = EdgeInsets.zero,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(45),
      child: Container(
        width: 54,
        height: 54,
        padding: const EdgeInsets.all(6.43),
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            side: borderColor != null
                ? BorderSide(width: 1, color: borderColor)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(45),
          ),
        ),
        child: Center(
          child: Padding(
            padding: imagePadding,
            child: Transform.scale(
              scale: imageScale,
              child: Image.asset(
                imagePath,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
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
        if (kakaoResult['needsServerAuth'] == true) {
          return;
        }
        return;
      }

      final kakaoData = kakaoResult['data'];
      final kakaoId = kakaoData['kakaoId']?.toString() ?? '';
      final email = kakaoData['email']?.toString();
      final nickname = kakaoData['nickname']?.toString();

      if (kakaoId.isEmpty) {
        if (!mounted) return;
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

        Future.microtask(() {
          if (!mounted) return;
          try {
            Navigator.of(context).pushReplacementNamed(_returnTo ?? '/home');
          } catch (_) {}
        });
      } else {
        if (!mounted) return;
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}