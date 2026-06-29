import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/kakao_auth_service.dart';
import '../../../data/services/naver_auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/kcp_cert.dart';
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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: Color(0xFF1A1A1A),
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 27),
                  vertical: healthDp(context, 20),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height -
                        healthDp(context, 40),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Form(
                      key: _formKey,
                      child: Container(
                        width: double.infinity,
                        constraints:
                            const BoxConstraints(maxWidth: 650),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 375 기준 로고 위 간격(기존 체감값): 331
                            SizedBox(height: healthDp(context, 130)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                healthDp(context, 37),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    AppAssets.bomioraPinkLogo,
                                    height: healthDp(context, 22),
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(height: healthDp(context, 40)),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildInputField(
                                        controller: _emailController,
                                        hintText: '이메일',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return '이메일을 입력해주세요';
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: healthDp(context, 10)),
                                      _buildPasswordField(),
                                      AnimatedSize(
                                        duration: const Duration(
                                            milliseconds: 180),
                                        curve: Curves.easeInOut,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_loginErrorText != null) ...[
                                              SizedBox(
                                                  height: healthDp(
                                                      context, 14)),
                                              Text(
                                                _loginErrorText!,
                                                style: TextStyle(
                                                  color: const Color(
                                                      0xFFEF4444),
                                                  fontSize: healthSp(
                                                      context, 12),
                                                  fontFamily:
                                                      'Gmarket Sans TTF',
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                            SizedBox(
                                              height: healthDp(
                                                context,
                                                _loginErrorText != null
                                                    ? 14
                                                    : 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _isLoading
                                            ? null
                                            : () => setState(() =>
                                                _autoLogin = !_autoLogin),
                                        borderRadius:
                                            BorderRadius.circular(
                                          healthDp(context, 6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 150),
                                              width:
                                                  healthDp(context, 20),
                                              height:
                                                  healthDp(context, 20),
                                              decoration: ShapeDecoration(
                                                color: _autoLogin
                                                    ? const Color(
                                                        0xFFFF5A8D)
                                                    : Colors.white,
                                                shape:
                                                    RoundedRectangleBorder(
                                                  side: BorderSide(
                                                    width: healthDp(
                                                        context, 0.5),
                                                    color: _autoLogin
                                                        ? const Color(
                                                            0xFFFF5A8D)
                                                        : const Color(
                                                            0xFF898383),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    healthDp(context, 4),
                                                  ),
                                                ),
                                              ),
                                              child: _autoLogin
                                                  ? Icon(
                                                      Icons.check,
                                                      size: healthDp(
                                                          context, 14),
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                            SizedBox(
                                                width: healthDp(context, 4)),
                                            Text(
                                              '자동로그인',
                                              style: TextStyle(
                                                color: const Color(
                                                    0xFF898383),
                                                fontSize:
                                                    healthSp(context, 12),
                                                fontFamily:
                                                    'Gmarket Sans TTF',
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: healthDp(context, 24)),
                                      _buildLoginButton(),
                                      SizedBox(height: healthDp(context, 20)),
                                      _buildLinkRow(),
                                    ],
                                  ),
                                  SizedBox(height: healthDp(context, 48)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildSocialIconButton(
                                        imagePath: AppAssets.loginNaver,
                                        onTap: _isLoading ? null : _handleNaverLogin,
                                      ),
                                      SizedBox(width: healthDp(context, 10)),
                                      _buildSocialIconButton(
                                        imagePath: AppAssets.loginKakao,
                                        onTap: _isLoading
                                            ? null
                                            : _handleKakaoLogin,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: healthDp(context, 6)),
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
          ),
        ),
      ),
    );
  }

  void _submitLoginFromKeyboard() {
    if (_isLoading) return;
    _handleLogin();
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
      height: healthDp(context, 52),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        validator: validator,
        onFieldSubmitted: (_) {
          if (_passwordController.text.trim().isNotEmpty) {
            _submitLoginFromKeyboard();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        onChanged: (_) {
          if (_loginErrorText != null) {
            setState(() => _loginErrorText = null);
          }
        },
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: healthSp(context, 16),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0x7F707070),
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 14),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: BorderSide(
              color: const Color(0xFFFF5A8D),
              width: healthDp(context, 1.2),
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: BorderSide(
              color: const Color(0xFFEF4444),
              width: healthDp(context, 1.2),
            ),
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 52),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '비밀번호를 입력해주세요';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submitLoginFromKeyboard(),
        onChanged: (_) {
          if (_loginErrorText != null) {
            setState(() => _loginErrorText = null);
          }
        },
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: healthSp(context, 16),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '비밀번호',
          hintStyle: TextStyle(
            color: const Color(0x7F707070),
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 14),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: const BorderSide(color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: BorderSide(
              color: const Color(0xFFFF5A8D),
              width: healthDp(context, 1.2),
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
            borderSide: BorderSide(
              color: const Color(0xFFEF4444),
              width: healthDp(context, 1.2),
            ),
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
      height: healthDp(context, 52),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A8D),
          disabledBackgroundColor: const Color(0xFFFF5A8D).withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: const Color(0x3F000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: healthDp(context, 10),
                width: healthDp(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: healthDp(context, 2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '로그인',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 16),
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
            child: Text(
              '아이디/비밀번호 찾기',
              style: TextStyle(
                color: Color(0xFF898383),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: healthDp(context, 1),
            height: healthDp(context, 15),
            margin: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
            color: const Color(0xFF898383),
          ),
          TextButton(
            onPressed: _isLoading ? null : _openSignup,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              '회원가입',
              style: TextStyle(
                color: Color(0xFF898383),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSignup() async {
    final cert = await Navigator.push<Map<String, dynamic>?>(
      context,
      PageRouteBuilder<Map<String, dynamic>?>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: const Color(0x991A1A1A),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const KcpCertWebViewScreen(
            flow: 'signup',
            popResultToParent: true,
          );
        },
      ),
    );
    if (!mounted || cert == null) return;

    if (cert['popupBlocked'] == true) return;

    if (cert['duplicate'] == true) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (cert['cert_completed'] != true) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SignupScreen(certInfo: cert),
      ),
    );
  }

  Widget _buildSocialIconButton({
    required String imagePath,
    required VoidCallback? onTap,
  }) {
    final size = healthDp(context, 54);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          imagePath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Future<void> _completeSocialLogin(Map<String, dynamic> result) async {
    final resultData = result['data'];
    if (resultData is! Map) {
      throw const FormatException('소셜 로그인 응답 형식이 올바르지 않습니다.');
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

    Navigator.of(context).pushReplacementNamed(_returnTo ?? '/home');
  }

  Future<void> _openSocialSignup({
    required String provider,
    required String identifier,
    String? email,
    String? nickname,
    String? name,
    String? gender,
    String? birthday,
    String? profileImageUrl,
    Map<String, dynamic>? prefill,
  }) async {
    final p = prefill != null ? NodeValueParser.normalizeMap(prefill) : null;
    await Navigator.pushNamed(
      context,
      '/social-signup',
      arguments: {
        'provider': provider,
        'identifier': identifier,
        'email': email ?? p?['email']?.toString(),
        'nickname': nickname ?? p?['nickname']?.toString(),
        'name': name ?? p?['name']?.toString(),
        'gender': gender ?? p?['gender']?.toString(),
        'birthday': birthday ?? p?['birthday']?.toString(),
        'profileImageUrl':
            profileImageUrl ?? p?['profileImageUrl']?.toString(),
      },
    );
  }

  Future<void> _handleSocialAuthResult(
    Map<String, dynamic> result, {
    required String provider,
    required String identifier,
    String? email,
    String? nickname,
    String? name,
    String? profileImageUrl,
    String? gender,
    String? birthday,
  }) async {
    if (result['success'] == true) {
      await _completeSocialLogin(result);
      return;
    }

    if (result['needRegister'] == true) {
      await _openSocialSignup(
        provider: provider,
        identifier: identifier,
        email: email,
        nickname: nickname,
        name: name,
        gender: gender,
        birthday: birthday,
        profileImageUrl: profileImageUrl,
        prefill: result['prefill'] is Map
            ? Map<String, dynamic>.from(result['prefill'] as Map)
            : null,
      );
      return;
    }

    if (!mounted) return;
    final msg = result['error']?.toString();
    if (msg != null && msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
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
        if (kakaoResult['needsServerAuth'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('웹 환경에서는 카카오 로그인을 지원하지 않습니다.'),
            ),
          );
        }
        return;
      }

      final kakaoData = kakaoResult['data'] as Map<String, dynamic>;
      final kakaoId = kakaoData['kakaoId']?.toString() ?? '';
      final email = kakaoData['email']?.toString();
      final nickname = kakaoData['nickname']?.toString();

      if (kakaoId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오 사용자 정보를 가져오지 못했습니다.')),
        );
        return;
      }

      final result = await AuthRepository.loginWithKakao(
        kakaoId: kakaoId,
        email: email,
        nickname: nickname,
        profileImageUrl: kakaoData['profileImageUrl']?.toString(),
        accessToken: kakaoData['accessToken']?.toString(),
      );

      await _handleSocialAuthResult(
        result,
        provider: 'kakao',
        identifier: kakaoId,
        email: email,
        nickname: nickname,
        profileImageUrl: kakaoData['profileImageUrl']?.toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인 오류: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleNaverLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final naverResult = await NaverAuthService.login();

      if (!naverResult['success']) {
        if (!mounted) return;
        if (naverResult['needsServerAuth'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('웹 환경에서는 네이버 로그인을 지원하지 않습니다.'),
            ),
          );
        } else if (naverResult['cancelled'] != true) {
          final msg = naverResult['error']?.toString();
          if (msg != null && msg.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        }
        return;
      }

      final naverData = naverResult['data'] as Map<String, dynamic>;
      final naverId = naverData['naverId']?.toString() ?? '';
      final email = naverData['email']?.toString();
      final nickname = naverData['nickname']?.toString();
      final name = naverData['name']?.toString();

      if (naverId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네이버 사용자 정보를 가져오지 못했습니다.')),
        );
        return;
      }

      final result = await AuthRepository.loginWithNaver(
        naverId: naverId,
        email: email,
        nickname: nickname,
        name: name,
        profileImageUrl: naverData['profileImageUrl']?.toString(),
        gender: naverData['gender']?.toString(),
        birthday: naverData['birthday']?.toString(),
        accessToken: naverData['accessToken']?.toString(),
      );

      await _handleSocialAuthResult(
        result,
        provider: 'naver',
        identifier: naverId,
        email: email,
        nickname: nickname,
        name: name,
        gender: naverData['gender']?.toString(),
        birthday: naverData['birthday']?.toString(),
        profileImageUrl: naverData['profileImageUrl']?.toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네이버 로그인 오류: $e')),
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