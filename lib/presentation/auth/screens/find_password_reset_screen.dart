import 'package:flutter/material.dart';

import '../../../core/validation/app_password_validator.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

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
  bool _isSubmitting = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

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

  bool get _hasPasswordRuleError =>
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
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    if (!_hasRequiredContext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인인증 정보가 올바르지 않습니다. 다시 시도해 주세요.')),
      );
      return;
    }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['data']?['message']?.toString() ?? '비밀번호가 변경되었습니다.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['error']?.toString() ?? '비밀번호 재설정에 실패했습니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(title: '비밀번호 재설정'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 5),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordSection(
                        title: '새 비밀번호를 입력해 주세요',
                        controller: _passwordController,
                        obscureText: _obscureNewPassword,
                        onToggleObscure: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        ),
                        hasError: _hasPasswordRuleError,
                        helperText: _hasPasswordRuleError
                            ? '*8~16자/문자,숫자,특수문자 모두 혼용'
                            : '*8~16자/문자,숫자,특수문자 모두 혼용',
                        helperColor: const Color(0xFF898686),
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordSection(
                        title: '새 비밀번호를 다시 한번 입력해 주세요',
                        controller: _confirmController,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
                        ),
                        hasError: _hasConfirmMismatch,
                        helperText: _hasConfirmMismatch
                            ? '비밀번호가 일치하지 않습니다.'
                            : null,
                        helperColor: const Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _handleSubmit : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _canSubmit
                                ? const Color(0xFFFF5A8D)
                                : const Color(0xFFD2D2D2),
                            disabledBackgroundColor: const Color(0xFFD2D2D2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  '변경하기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
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
            ],
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            obscureText: obscureText,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF898686),
                  size: 22,
                ),
                tooltip: obscureText ? '비밀번호 표시' : '비밀번호 숨기기',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  width: 1,
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFD2D2D2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  width: 1,
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFD2D2D2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  width: 1,
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFFF5A8D),
                ),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 2),
            Text(
              helperText,
              style: TextStyle(
                color: helperColor,
                fontSize: 10,
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
