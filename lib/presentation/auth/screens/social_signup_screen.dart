import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/user/user_model.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/last_login_via_service.dart';
import '../../../data/services/pending_product_checkout.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widgets/agreement_widget.dart';

enum _KakaoSignupStep { phone, agreement }

/// 웹 `social_register_member.skin.php` 와 동일: 소셜 OAuth 후 휴대폰(+ 네이버 이메일) 입력
class SocialSignupScreen extends StatefulWidget {
  final String provider;
  final String identifier;
  final String? email;
  final String? nickname;
  final String? name;
  final String? gender;
  final String? birthday;
  final String? profileImageUrl;
  final String? identityToken;
  final String? authorizationCode;

  const SocialSignupScreen({
    super.key,
    required this.provider,
    required this.identifier,
    this.email,
    this.nickname,
    this.name,
    this.gender,
    this.birthday,
    this.profileImageUrl,
    this.identityToken,
    this.authorizationCode,
  });

  @override
  State<SocialSignupScreen> createState() => _SocialSignupScreenState();
}

class _SocialSignupScreenState extends State<SocialSignupScreen> {
  final _hp1 = TextEditingController(text: '010');
  final _hp2 = TextEditingController();
  final _hp3 = TextEditingController();
  late final TextEditingController _emailController;

  final _codeController = TextEditingController();

  final _hp1Focus = FocusNode();
  final _hp2Focus = FocusNode();
  final _hp3Focus = FocusNode();
  final _emailFocus = FocusNode();

  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  bool _appPush = false;
  bool _isLoading = false;
  String? _errorText;

  _KakaoSignupStep _kakaoStep = _KakaoSignupStep.phone;
  Timer? _verifyTimer;
  int _secondsLeft = 0;
  String? _otpToken;
  String? _otpVerifiedDigits;
  bool _otpSending = false;
  bool _otpVerifying = false;

  bool get _isKakao => widget.provider.toLowerCase() == 'kakao';
  bool get _isNaver => widget.provider.toLowerCase() == 'naver';
  bool get _isApple => widget.provider.toLowerCase() == 'apple';
  bool get _showEmailField => !_isKakao &&
      (_isNaver ||
          _isApple ||
          (widget.email == null || widget.email!.trim().isEmpty));

  String get _phoneDigits =>
      '${_hp1.text.trim()}${_hp2.text.trim()}${_hp3.text.trim()}';

  static const _phoneInvalidMessage = '휴대폰 번호를 올바르게 입력해 주세요.';

  bool get _kakaoPhoneVerified =>
      _otpVerifiedDigits != null && _otpVerifiedDigits == _phoneDigits;

  bool get _phoneReadyToSend =>
      _hp1.text.trim().length == 3 &&
      _hp2.text.trim().length == 4 &&
      _hp3.text.trim().length == 4;

  bool get _confirmOtpActive =>
      !_kakaoPhoneVerified && _otpToken != null && _otpToken!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _hp1.dispose();
    _hp2.dispose();
    _hp3.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _verifyTimer?.cancel();
    _hp1Focus.dispose();
    _hp2Focus.dispose();
    _hp3Focus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  String get _phone =>
      '${_hp1.text.trim()}-${_hp2.text.trim()}-${_hp3.text.trim()}';

  String _formatPhone(String digits) {
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return digits;
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remain = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remain';
  }

  void _startCountdown(int seconds) {
    _verifyTimer?.cancel();
    _secondsLeft = seconds;
    if (mounted) setState(() {});
    _verifyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _onKakaoPhoneChanged() {
    if (!_isKakao) return;
    final invalidateOtp = !_kakaoPhoneVerified &&
        (_otpToken != null || _otpVerifiedDigits != null || _secondsLeft > 0);
    if (invalidateOtp) _verifyTimer?.cancel();
    setState(() {
      if (invalidateOtp) {
        _otpToken = null;
        _otpVerifiedDigits = null;
        _secondsLeft = 0;
        if (_errorText != _phoneInvalidMessage) _errorText = null;
      }
      if (_phoneReadyToSend && _errorText == _phoneInvalidMessage) {
        _errorText = null;
      }
    });
  }

  Future<void> _requestKakaoOtp() async {
    final digits = _phoneDigits;
    if (!_phoneReadyToSend) {
      setState(() => _errorText = _phoneInvalidMessage);
      return;
    }

    setState(() {
      _otpSending = true;
      _errorText = null;
      _otpToken = null;
      _otpVerifiedDigits = null;
    });

    final name = (widget.name ?? widget.nickname ?? '').trim();
    final send = await AuthRepository.otpSend(
      purpose: 'social_signup',
      name: name.isEmpty ? '회원' : name,
      phone: _formatPhone(digits),
    );
    if (!mounted) return;
    setState(() => _otpSending = false);

    if (send['success'] != true) {
      setState(() {
        _errorText = send['error']?.toString() ?? '인증번호 발송에 실패했습니다.';
      });
      return;
    }

    final token = send['otpToken']?.toString();
    if (token == null || token.isEmpty) {
      setState(() => _errorText = '인증 응답이 올바르지 않습니다.');
      return;
    }

    final ttl = int.tryParse(send['ttlSeconds']?.toString() ?? '');
    setState(() {
      _otpToken = token;
      _codeController.clear();
      _errorText = null;
    });
    _startCountdown((ttl != null && ttl > 0 && ttl <= 600) ? ttl : 180);
  }

  Future<void> _confirmKakaoOtp() async {
    final token = _otpToken;
    final code = _codeController.text.trim();
    if (token == null || token.isEmpty) {
      setState(() => _errorText = '인증번호를 받아 주세요.');
      return;
    }
    if (code.length < 6) {
      setState(() => _errorText = '인증번호 6자리를 입력해 주세요.');
      return;
    }

    setState(() {
      _otpVerifying = true;
      _errorText = null;
    });
    final verify = await AuthRepository.otpVerify(
      otpToken: token,
      code: code,
      purpose: 'social_signup',
    );
    if (!mounted) return;
    setState(() => _otpVerifying = false);

    if (verify['success'] != true) {
      setState(() {
        _errorText = verify['error']?.toString() ?? '인증에 실패했습니다.';
      });
      return;
    }

    _verifyTimer?.cancel();
    setState(() {
      _otpVerifiedDigits = _phoneDigits;
      _otpToken = null;
      _secondsLeft = 0;
      _errorText = null;
    });
  }

  void _goToKakaoAgreement() {
    if (!_kakaoPhoneVerified) return;
    setState(() {
      _kakaoStep = _KakaoSignupStep.agreement;
      _errorText = null;
    });
  }

  void _handleKakaoBack() {
    if (_kakaoStep == _KakaoSignupStep.agreement) {
      setState(() => _kakaoStep = _KakaoSignupStep.phone);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _submit([Map<String, bool>? agreements]) async {
    final phoneDigits = _isKakao
        ? (_otpVerifiedDigits ?? '')
        : _phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length < 10) {
      setState(() => _errorText = '휴대폰 번호를 올바르게 입력해 주세요.');
      return;
    }
    if (_isKakao && !_kakaoPhoneVerified) {
      setState(() => _errorText = '인증번호를 확인해 주세요.');
      return;
    }

    final email = _isKakao
        ? (widget.email ?? '').trim()
        : _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorText = _isKakao
            ? '카카오 이메일 정보를 가져오지 못했습니다.'
            : '이메일을 입력해 주세요.';
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorText = '올바른 이메일 형식을 입력해 주세요.');
      return;
    }

    if (!_isKakao && (!_terms || !_privacy)) {
      setState(() => _errorText = '필수 약관에 동의해 주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final result = await AuthRepository.registerWithSocial(
      provider: widget.provider,
      identifier: widget.identifier,
      phone: _formatPhone(phoneDigits),
      email: email,
      name: widget.name ?? widget.nickname ?? email.split('@').first,
      nickname: widget.nickname,
      gender: widget.gender,
      birthday: widget.birthday,
      profileImageUrl: widget.profileImageUrl,
      identityToken: widget.identityToken,
      authorizationCode: widget.authorizationCode,
      agreements: agreements ??
          {
            'terms': _terms,
            'privacy': _privacy,
            'marketing': _marketing,
            'marketingEmail': _marketing,
            'marketingSms': _marketing,
            'appPush': _appPush,
          },
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final data = NodeValueParser.normalizeMap(
        Map<String, dynamic>.from(result['data'] as Map? ?? {}),
      );
      final userRaw = data['user'];
      final userJson = NodeValueParser.normalizeMap(
        userRaw is Map
            ? Map<String, dynamic>.from(userRaw)
            : Map<String, dynamic>.from(data),
      );
      final userId =
          NodeValueParser.asString(userJson['mb_id']) ??
          NodeValueParser.asString(userJson['id']) ??
          '';
      userJson['id'] = userId;

      await AuthService.saveLoginData(
        user: UserModel.fromJson(userJson),
        token: NodeValueParser.asString(data['token']),
      );
      await LastLoginViaService.save(
        LastLoginViaService.normalize(widget.provider) ??
            LastLoginViaService.kakao,
      );

      if (!mounted) return;
      if (PendingProductCheckout.navigateAfterAuth(context)) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/signup-done', (route) => false);
      return;
    }

    final message = result['error']?.toString() ?? '회원가입에 실패했습니다.';
    setState(() {
      _isLoading = false;
      _errorText = message;
    });
    if (_isKakao && _kakaoStep == _KakaoSignupStep.agreement) {
      AppToastOverlay.show(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = _isApple
        ? 'Apple'
        : _isNaver
            ? '네이버'
            : '카카오';

    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: '$providerLabel 회원가입',
        leadingIconSize: healthDp(context, 24),
        onBack: _isKakao ? _handleKakaoBack : null,
      ),
      child: _isKakao
          ? (_kakaoStep == _KakaoSignupStep.agreement
              ? AgreementWidget(
                  isLoading: _isLoading,
                  onNext: _submit,
                )
              : _buildKakaoPhoneStep())
          : _buildLegacySignup(),
    );
  }

  Widget _buildLegacySignup() {
    return SafeArea(
      child: SingleChildScrollView(
            padding: EdgeInsets.all(healthDp(context, 24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '전화번호 입력',
                  style: TextStyle(
                    fontFamily: 'Gmarket Sans TTF',
                    fontSize: healthSp(context, 18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: healthDp(context, 8)),
                Text(
                  '소셜 로그인 후 서비스 이용을 위해 휴대폰 번호가 필요합니다.',
                  style: TextStyle(
                    fontFamily: 'Gmarket Sans TTF',
                    fontSize: healthSp(context, 13),
                    color: const Color(0xFF898686),
                  ),
                ),
                SizedBox(height: healthDp(context, 24)),
                _buildPhoneRow(),
                if (_showEmailField) ...[
                  SizedBox(height: healthDp(context, 20)),
                  TextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontSize: healthSp(context, 16),
                    ),
                    decoration: InputDecoration(
                      labelText: '이메일',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 12),
                        vertical: healthDp(context, 12),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(healthDp(context, 8)),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: healthDp(context, 20)),
                CheckboxListTile(
                  value: _terms,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _terms = v ?? false),
                  title: Text(
                    '이용약관 동의 (필수)',
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontSize: healthSp(context, 14),
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                CheckboxListTile(
                  value: _privacy,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _privacy = v ?? false),
                  title: Text(
                    '개인정보 처리방침 동의 (필수)',
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontSize: healthSp(context, 14),
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                CheckboxListTile(
                  value: _marketing,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _marketing = v ?? false),
                  title: Text(
                    '마케팅 정보 수신 동의 (선택)',
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontSize: healthSp(context, 14),
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                CheckboxListTile(
                  value: _appPush,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _appPush = v ?? false),
                  title: Text(
                    '야간 알림 (선택)',
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontSize: healthSp(context, 14),
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                if (_errorText != null) ...[
                  SizedBox(height: healthDp(context, 12)),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: healthSp(context, 13),
                    ),
                  ),
                ],
                SizedBox(height: healthDp(context, 24)),
                FilledButton(
                  onPressed: _isLoading || !_terms || !_privacy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A8D),
                    minimumSize: Size.fromHeight(healthDp(context, 48)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 8)),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: healthDp(context, 22),
                          height: healthDp(context, 22),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '회원가입',
                          style: TextStyle(
                            fontFamily: 'Gmarket Sans TTF',
                            fontSize: healthSp(context, 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildKakaoPhoneStep() {
    final canNext = _kakaoPhoneVerified && !_isLoading;
    final hasError = _errorText != null && _errorText!.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: healthDp(context, 20)),
                Text(
                  '환영합니다.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 20),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -1.8),
                    height: 1,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  '휴대폰 번호를 인증해 주세요.',
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: healthSp(context, -1.44),
                    height: 1,
                  ),
                ),
                SizedBox(height: healthDp(context, 30)),
                Text(
                  '휴대폰 번호',
                  style: _kakaoFieldLabelStyle(),
                ),
                SizedBox(height: healthDp(context, 5)),
                SizedBox(
                  height: healthDp(context, 40),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildKakaoPhoneBoxes(
                          hasError: _errorText == _phoneInvalidMessage,
                        ),
                      ),
                      SizedBox(width: healthDp(context, 8)),
                      _kakaoSideButton(
                        label: _otpSending ? '발송 중…' : '발송',
                        enabled: _phoneReadyToSend && !_otpSending,
                        onPressed: _requestKakaoOtp,
                      ),
                    ],
                  ),
                ),
                if (_errorText == _phoneInvalidMessage) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    _phoneInvalidMessage,
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
                SizedBox(height: healthDp(context, 10)),
                Text(
                  '인증번호',
                  style: _kakaoFieldLabelStyle(),
                ),
                SizedBox(height: healthDp(context, 5)),
                SizedBox(
                  height: healthDp(context, 40),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          expands: true,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.center,
                          cursorColor: const Color(0xFF1A1A1A),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) {
                            if (_errorText != null &&
                                _errorText != _phoneInvalidMessage) {
                              setState(() => _errorText = null);
                            }
                          },
                          style: _kakaoInputStyle(),
                          decoration: _kakaoInputDecoration(
                            hintText: '인증번호를 입력해 주세요',
                            hasError: hasError &&
                                _errorText != _phoneInvalidMessage,
                          ),
                        ),
                      ),
                      if (_secondsLeft > 0) ...[
                        SizedBox(width: healthDp(context, 8)),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: healthDp(context, 14),
                                color: const Color(0xFFFF5A8D),
                              ),
                              SizedBox(width: healthDp(context, 2)),
                              Text(
                                _formatTime(_secondsLeft),
                                style: TextStyle(
                                  color: const Color(0xFFFF5A8D),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontSize: healthSp(context, 12),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(width: healthDp(context, 8)),
                      _kakaoSideButton(
                        label: _otpVerifying ? '확인 중…' : '확인',
                        enabled: _confirmOtpActive &&
                            !_otpVerifying &&
                            !_otpSending,
                        onPressed: _confirmKakaoOtp,
                        filledWhenDisabled: _confirmOtpActive,
                      ),
                    ],
                  ),
                ),
                if (hasError && _errorText != _phoneInvalidMessage) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ] else if (_kakaoPhoneVerified) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    '인증번호가 확인되었습니다.',
                    style: TextStyle(
                      color: const Color(0xFF16A34A),
                      fontSize: healthSp(context, 10),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 20),
              healthDp(context, 10),
              healthDp(context, 20),
              healthDp(context, 10),
            ),
            child: SizedBox(
              width: double.infinity,
              height: healthDp(context, 40),
              child: ElevatedButton(
                onPressed: canNext ? _goToKakaoAgreement : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: canNext
                      ? const Color(0xFFFF5A8D)
                      : const Color(0xFFD2D2D2),
                  disabledBackgroundColor: const Color(0xFFD2D2D2),
                  disabledForegroundColor: Colors.white,
                  padding: EdgeInsets.all(healthDp(context, 10)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  '다음',
                  textAlign: TextAlign.center,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _kakaoFieldLabelStyle() {
    return TextStyle(
      color: Colors.black,
      fontSize: healthSp(context, 16),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }

  TextStyle _kakaoInputStyle() {
    return TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: healthSp(context, 16),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }

  InputDecoration _kakaoInputDecoration({
    String? hintText,
    bool hasError = false,
  }) {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        borderSide: BorderSide(
          width: healthDp(context, 1),
          color: color,
        ),
      );
    }

    final idle = hasError ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2);
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: const Color(0xFFB8B8B8),
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w300,
        height: 1,
      ),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: 0,
      ),
      border: border(idle),
      enabledBorder: border(idle),
      focusedBorder: border(const Color(0xFFFF5A8D)),
    );
  }

  Widget _kakaoSideButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    bool filledWhenDisabled = false,
  }) {
    final pink = enabled || filledWhenDisabled;
    return SizedBox(
      width: healthDp(context, 76),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              pink ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
          disabledBackgroundColor:
              pink ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
          disabledForegroundColor: Colors.white,
          minimumSize: Size(healthDp(context, 76), healthDp(context, 40)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: healthSp(context, 13),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildKakaoPhoneBoxes({bool hasError = false}) {
    Widget part(
      TextEditingController controller, {
      required FocusNode focusNode,
      required int maxLen,
      FocusNode? nextFocus,
      FocusNode? previousFocus,
    }) {
      return Expanded(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          expands: true,
          maxLines: null,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          cursorColor: const Color(0xFF1A1A1A),
          textInputAction:
              nextFocus != null ? TextInputAction.next : TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLen),
          ],
          onChanged: (value) {
            _onKakaoPhoneChanged();
            if (value.length >= maxLen) {
              if (nextFocus != null) {
                nextFocus.requestFocus();
              } else {
                focusNode.unfocus();
              }
            } else if (value.isEmpty && previousFocus != null) {
              previousFocus.requestFocus();
            }
          },
          style: _kakaoInputStyle(),
          decoration: _kakaoInputDecoration(hasError: hasError),
        ),
      );
    }

    Widget gap() => SizedBox(width: healthDp(context, 7));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        part(
          _hp1,
          focusNode: _hp1Focus,
          maxLen: 3,
          nextFocus: _hp2Focus,
        ),
        gap(),
        SizedBox(
          width: healthDp(context, 15),
          child: Center(
            child: Container(
              width: healthDp(context, 15),
              height: healthDp(context, 1),
              color: const Color(0xFFD9D9D9),
            ),
          ),
        ),
        gap(),
        part(
          _hp2,
          focusNode: _hp2Focus,
          maxLen: 4,
          nextFocus: _hp3Focus,
          previousFocus: _hp1Focus,
        ),
        gap(),
        SizedBox(
          width: healthDp(context, 15),
          child: Center(
            child: Container(
              width: healthDp(context, 15),
              height: healthDp(context, 1),
              color: const Color(0xFFD9D9D9),
            ),
          ),
        ),
        gap(),
        part(
          _hp3,
          focusNode: _hp3Focus,
          maxLen: 4,
          previousFocus: _hp2Focus,
        ),
      ],
    );
  }

  Widget _buildPhoneRow({bool showHints = true}) {
    Widget part(
      TextEditingController c, {
      required FocusNode focusNode,
      required int maxLen,
      FocusNode? nextFocus,
      FocusNode? previousFocus,
      String? hint,
      TextInputAction? action,
    }) {
      return Expanded(
        child: TextField(
          controller: c,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: action ??
              (nextFocus != null
                  ? TextInputAction.next
                  : TextInputAction.done),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLen),
          ],
          textAlign: TextAlign.center,
          onChanged: (value) {
            _onKakaoPhoneChanged();
            if (value.length >= maxLen) {
              if (nextFocus != null) {
                nextFocus.requestFocus();
              } else {
                focusNode.unfocus();
              }
            } else if (value.isEmpty && previousFocus != null) {
              previousFocus.requestFocus();
            }
          },
          onSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              focusNode.unfocus();
            }
          },
          style: TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            fontSize: healthSp(context, 16),
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: healthDp(context, 12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        part(
          _hp1,
          focusNode: _hp1Focus,
          maxLen: 3,
          nextFocus: _hp2Focus,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
          child: const Text('-'),
        ),
        part(
          _hp2,
          focusNode: _hp2Focus,
          maxLen: 4,
          nextFocus: _hp3Focus,
          previousFocus: _hp1Focus,
          hint: showHints ? '1234' : null,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
          child: const Text('-'),
        ),
        part(
          _hp3,
          focusNode: _hp3Focus,
          maxLen: 4,
          nextFocus: _showEmailField ? _emailFocus : null,
          previousFocus: _hp2Focus,
          hint: showHints ? '5678' : null,
        ),
      ],
    );
  }
}
