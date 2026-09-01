import 'package:flutter/material.dart';

import '../../../core/validation/app_password_validator.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

class FindPasswordResetScreen extends StatefulWidget {
  const FindPasswordResetScreen({
    super.key,
    this.resetInfo,
  });

  final Map<String, dynamic>? resetInfo;

  @override
  State<FindPasswordResetScreen> createState() =>
      _FindPasswordResetScreenState();
}

class _FindPasswordResetScreenState extends State<FindPasswordResetScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  bool _isSubmitting = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  /// 새 비밀번호 칸을 벗어난 뒤에만 규칙 위반 테두리/안내색 표시
  bool _showPasswordRuleError = false;

  static const Color _kHelperMuted = Color(0xFF898686);
  static const Color _kError = Color(0xFFEF4444);

  String get _email => (widget.resetInfo?['email'] ?? '').toString().trim();
  String get _identifier =>
      (widget.resetInfo?['identifier'] ?? widget.resetInfo?['email'] ?? '')
          .toString()
          .trim();
  String get _name => (widget.resetInfo?['name'] ?? '').toString().trim();
  String get _phone => (widget.resetInfo?['phone'] ?? '').toString().trim();
  String get _otpToken =>
      (widget.resetInfo?['otpToken'] ?? widget.resetInfo?['otp_token'] ?? '')
          .toString()
          .trim();
  bool get _fromKcp =>
      widget.resetInfo?['from_kcp'] == true || widget.resetInfo?['fromKcp'] == true;
  String get _mbDupinfo =>
      (widget.resetInfo?['mb_dupinfo'] ?? widget.resetInfo?['mbDupinfo'] ?? '')
          .toString()
          .trim();

  bool get _passwordFailsRule =>
      _passwordController.text.isNotEmpty &&
      !isValidAppPassword(_passwordController.text);

  bool get _hasConfirmMismatch =>
      _confirmController.text.isNotEmpty &&
      _passwordController.text != _confirmController.text;

  bool get _hasRequiredContext {
    if (_fromKcp) {
      return _mbDupinfo.isNotEmpty && _identifier.isNotEmpty;
    }
    return _name.isNotEmpty &&
        _phone.isNotEmpty &&
        _otpToken.isNotEmpty &&
        _identifier.isNotEmpty;
  }

  bool get _canSubmit =>
      _hasRequiredContext &&
      isValidAppPassword(_passwordController.text) &&
      _passwordController.text == _confirmController.text &&
      !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(_onPasswordFocusChange);
  }

  void _onPasswordFocusChange() {
    if (_passwordFocus.hasFocus) return;
    // 다음 칸으로 넘어간 뒤: 문제 있으면 에러, 없으면 해제
    final show = _passwordFailsRule;
    if (_showPasswordRuleError == show) return;
    setState(() => _showPasswordRuleError = show);
  }

  void _onPasswordChanged() {
    setState(() {
      // 고쳐서 규칙 통과하면 즉시 빨간 테두리/안내색 제거
      if (_showPasswordRuleError && !_passwordFailsRule) {
        _showPasswordRuleError = false;
      }
    });
  }

  @override
  void dispose() {
    _passwordFocus.removeListener(_onPasswordFocusChange);
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    if (!_hasRequiredContext) return;

    setState(() {
      _isSubmitting = true;
    });

    final result = await AuthRepository.resetPassword(
      name: _name,
      phone: _phone,
      password: _passwordController.text,
      email: _email.isNotEmpty ? _email : null,
      identifier: _identifier,
      otpToken: _fromKcp ? null : _otpToken,
      fromKcp: _fromKcp,
      mbDupinfo: _fromKcp && _mbDupinfo.isNotEmpty ? _mbDupinfo : null,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
      return;
    }

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
            appBar: HealthAppBar(
              title: '비밀번호 재설정',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 20),
                  healthDp(context, 20),
                  healthDp(context, 20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPasswordSection(
                              title: '새 비밀번호를 입력해 주세요',
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _confirmFocus.requestFocus(),
                              onChanged: _onPasswordChanged,
                              obscureText: _obscureNewPassword,
                              onToggleObscure: () => setState(
                                () => _obscureNewPassword =
                                    !_obscureNewPassword,
                              ),
                              hasError: _showPasswordRuleError,
                              helperText: '*8~16자/문자,숫자,특수문자 모두 혼용',
                              helperColor: _showPasswordRuleError
                                  ? _kError
                                  : _kHelperMuted,
                            ),
                            SizedBox(height: healthDp(context, 20)),
                            _buildPasswordSection(
                              title: '새 비밀번호를 다시 한번 입력해 주세요',
                              controller: _confirmController,
                              focusNode: _confirmFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (_canSubmit) _handleSubmit();
                              },
                              obscureText: _obscureConfirmPassword,
                              onToggleObscure: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                              hasError: _hasConfirmMismatch,
                              helperText: _hasConfirmMismatch
                                  ? '비밀번호가 일치하지 않습니다.'
                                  : null,
                              helperColor: _kError,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    SizedBox(
                      width: double.infinity,
                      height: healthDp(context, 40),
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _handleSubmit : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _canSubmit
                              ? const Color(0xFFFF5A8D)
                              : const Color(0xFFD2D2D2),
                          disabledBackgroundColor: const Color(0xFFD2D2D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              healthDp(context, 10),
                            ),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: healthDp(context, 18),
                                height: healthDp(context, 18),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                '변경하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: healthSp(context, 20),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordSection({
    required String title,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required bool hasError,
    required String? helperText,
    required Color helperColor,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: (_) {
              if (onChanged != null) {
                onChanged();
              } else {
                setState(() {});
              }
            },
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 10),
                vertical: healthDp(context, 12),
              ),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF898686),
                  size: healthDp(context, 22),
                ),
                tooltip: obscureText ? '비밀번호 표시' : '비밀번호 숨기기',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                borderSide: BorderSide(
                  width: healthDp(context, 1),
                  color: hasError ? _kError : const Color(0xFFD2D2D2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                borderSide: BorderSide(
                  width: healthDp(context, 1),
                  color: hasError ? _kError : const Color(0xFFD2D2D2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                borderSide: BorderSide(
                  width: healthDp(context, 1),
                  color: hasError ? _kError : const Color(0xFFFF5A8D),
                ),
              ),
            ),
          ),
          if (helperText != null) ...[
            SizedBox(height: healthDp(context, 2)),
            Text(
              helperText,
              style: TextStyle(
                color: helperColor,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
