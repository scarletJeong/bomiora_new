import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../utils/find_id_accounts.dart';
import '../widgets/find_account_btn.dart';
import '../widgets/registered_account_ui.dart';

enum _FindAccountTab { id, password }
enum _FindAccountStep { form, result }

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({
    super.key,
    this.initialTab = 'id',
    this.prefillEmail,
  });

  final String initialTab;
  /// 비밀번호 찾기 탭 진입 시 가입 이메일 자동 입력
  final String? prefillEmail;

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen> {
  final _idFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _idNameController = TextEditingController();
  final _passwordEmailController = TextEditingController();
  final _passwordNameController = TextEditingController();
  final _phoneMidController = TextEditingController();
  final _phoneLastController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  _FindAccountTab _selectedTab = _FindAccountTab.id;
  _FindAccountStep _step = _FindAccountStep.form;

  bool _isLoading = false;
  bool _isRegisteredPhoneExpanded = false;
  bool _isPhoneCertExpanded = false;
  bool _isCodeSent = false;
  bool _isCodeExpired = false;
  int _remainingSeconds = 0;
  String? _otpToken;
  int _otpTtlSeconds = 180;
  int _resendCooldownSeconds = 0;

  String? _emailLookupErrorText;
  String? _verificationErrorText;
  String? _verificationInfoText;
  /// 휴대폰 번호 행 바로 아래 표시(발송 전 검증, 인증 만료 등). 분홍 박스 미사용.
  String? _phoneInlineErrorText;
  List<String> _foundAccounts = [];
  int _selectedFoundAccountIndex = 0;
  Timer? _countdownTimer;
  Timer? _resendCooldownTimer;

  @override
  void dispose() {
    _idNameController.dispose();
    _passwordEmailController.dispose();
    _passwordNameController.dispose();
    _phoneMidController.dispose();
    _phoneLastController.dispose();
    _verificationCodeController.dispose();
    _countdownTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  String get _phoneNumber =>
      '010${_phoneMidController.text.trim()}${_phoneLastController.text.trim()}';

  bool get _canSubmit {
    if (_step == _FindAccountStep.result) return true;

    final hasBaseFields = _selectedTab == _FindAccountTab.id
        ? _idNameController.text.trim().isNotEmpty
        : _passwordEmailController.text.trim().isNotEmpty &&
            _passwordNameController.text.trim().isNotEmpty;

    return hasBaseFields &&
        _phoneMidController.text.trim().length >= 3 &&
        _phoneLastController.text.trim().length >= 4 &&
        _verificationCodeController.text.trim().isNotEmpty &&
        _isCodeSent &&
        !_isCodeExpired;
  }

  void _clearMessages() {
    _emailLookupErrorText = null;
    _verificationErrorText = null;
    _verificationInfoText = null;
    _phoneInlineErrorText = null;
  }

  void _handleFieldChanged(String _) {
    setState(() {
      _clearMessages();
    });
  }

  void _resetForTab(_FindAccountTab tab, {String? prefillPasswordEmail}) {
    _countdownTimer?.cancel();
    _resendCooldownTimer?.cancel();
    setState(() {
      _selectedTab = tab;
      _step = _FindAccountStep.form;
      _isRegisteredPhoneExpanded = false;
      _isPhoneCertExpanded = false;
      _isCodeSent = false;
      _isCodeExpired = false;
      _remainingSeconds = 0;
      _resendCooldownSeconds = 0;
      _otpToken = null;
      _otpTtlSeconds = 180;
      _idNameController.clear();
      _passwordEmailController.clear();
      _passwordNameController.clear();
      _phoneMidController.clear();
      _phoneLastController.clear();
      _verificationCodeController.clear();
      _foundAccounts = [];
      _selectedFoundAccountIndex = 0;
      _clearMessages();
      if (tab == _FindAccountTab.password) {
        final pre = prefillPasswordEmail?.trim();
        if (pre != null && pre.isNotEmpty) {
          _passwordEmailController.text = pre;
        }
      }
    });
  }

  void _startResendCooldown({int seconds = 5}) {
    _resendCooldownTimer?.cancel();
    _resendCooldownSeconds = seconds;
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        t.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds -= 1);
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedTab =
        widget.initialTab == 'password' ? _FindAccountTab.password : _FindAccountTab.id;
    final pre = widget.prefillEmail?.trim();
    if (pre != null && pre.isNotEmpty && _selectedTab == _FindAccountTab.password) {
      _passwordEmailController.text = pre;
    }
  }

  String get _remainingTimeText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = _otpTtlSeconds;
    _isCodeExpired = false;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isCodeExpired = true;
          _isCodeSent = false;
          _otpToken = null;
          _verificationCodeController.clear();
          _verificationErrorText = '인증시간이 만료되었습니다. 다시 발송해 주세요.';
          _verificationInfoText = null;
        });
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  Future<void> _handleSendCode() async {
    final hasEnoughData = _selectedTab == _FindAccountTab.id
        ? _idNameController.text.trim().isNotEmpty
        : _passwordEmailController.text.trim().isNotEmpty &&
            _passwordNameController.text.trim().isNotEmpty;

    if (!hasEnoughData ||
        _phoneMidController.text.trim().length < 3 ||
        _phoneLastController.text.trim().length < 4) {
      setState(() {
        _phoneInlineErrorText = '이름과 휴대폰 번호를 먼저 입력해 주세요.';
      });
      return;
    }

    if (_resendCooldownSeconds > 0) {
      setState(() {
        _phoneInlineErrorText = '재전송은 $_resendCooldownSeconds초 후에 가능합니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isCodeSent = false;
      _isCodeExpired = false;
      _otpToken = null;
      _verificationErrorText = null;
      _verificationInfoText = null;
      _phoneInlineErrorText = null;
    });

    final purpose = _selectedTab == _FindAccountTab.password
        ? 'password_find'
        : 'id_find';
    final name = _selectedTab == _FindAccountTab.password
        ? _passwordNameController.text.trim()
        : _idNameController.text.trim();
    final send = await AuthRepository.otpSend(
      purpose: purpose,
      name: name,
      phone: _phoneNumber,
    );

    if (!mounted) return;

    if (send['success'] != true) {
      setState(() {
        _isLoading = false;
        _phoneInlineErrorText = send['error']?.toString() ?? '인증번호 발송에 실패했습니다.';
      });
      return;
    }

    final token = send['otpToken']?.toString();
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _phoneInlineErrorText = '인증번호 발송 응답이 올바르지 않습니다. (otpToken 누락)';
      });
      return;
    }

    final ttl = int.tryParse(send['ttlSeconds']?.toString() ?? '');
    final ttlSeconds = (ttl != null && ttl > 0 && ttl <= 600) ? ttl : 180;

    setState(() {
      _isLoading = false;
      _isCodeSent = true;
      _isCodeExpired = false;
      _otpToken = token;
      _otpTtlSeconds = ttlSeconds;
      _verificationCodeController.clear();
      _verificationInfoText = '인증번호가 발송되었습니다.';
    });
    _startResendCooldown(seconds: 5);
    _startCountdown();
  }

  void _goToFindAccountNotFound([Map<String, dynamic>? arguments]) {
    Navigator.pushReplacementNamed(
      context,
      '/find-account-not-found',
      arguments: arguments,
    );
  }

  void _handlePhoneCertNavigation() {
    if (_selectedTab == _FindAccountTab.password) {
      final email = _passwordEmailController.text.trim();
      if (email.isEmpty) {
        setState(() {
          _emailLookupErrorText = '가입 이메일을 입력해 주세요.';
        });
        return;
      }

      Navigator.pushNamed(
        context,
        '/kcp-cert',
        arguments: {
          'flow': 'find-password',
          'email': email,
        },
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/kcp-cert',
      arguments: {
        'flow': 'find-account',
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (_step == _FindAccountStep.result) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final formValid = _selectedTab == _FindAccountTab.id
        ? _idFormKey.currentState?.validate() ?? false
        : _passwordFormKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final token = _otpToken;
    if (token == null || token.isEmpty || !_isCodeSent || _isCodeExpired) {
      setState(() {
        _verificationErrorText = '인증번호를 다시 발송해 주세요.';
      });
      return;
    }

    final purpose = _selectedTab == _FindAccountTab.password
        ? 'password_find'
        : 'id_find';
    final verify = await AuthRepository.otpVerify(
      otpToken: token,
      code: _verificationCodeController.text.trim(),
      purpose: purpose,
    );
    if (!mounted) return;
    if (verify['success'] != true) {
      final code = verify['code']?.toString();
      final msg = verify['error']?.toString() ?? '인증에 실패했습니다.';
      if (code == 'EXPIRED') {
        _countdownTimer?.cancel();
        setState(() {
          _isCodeExpired = true;
          _isCodeSent = false;
          _otpToken = null;
          _remainingSeconds = 0;
          _verificationErrorText = '인증시간이 만료되었습니다. 다시 발송해 주세요.';
          _verificationInfoText = null;
        });
        return;
      }

      setState(() {
        _verificationErrorText = msg;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _clearMessages();
    });

    try {
      if (_selectedTab == _FindAccountTab.id) {
        final result = await AuthRepository.findId(
          name: _idNameController.text.trim(),
          phone: _phoneNumber,
          otpToken: token,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          _countdownTimer?.cancel();
          final accounts = parseFindIdAccountEmails(result);

          if (accounts.isEmpty) {
            _goToFindAccountNotFound();
            return;
          }
          setState(() {
            _foundAccounts = accounts;
            _selectedFoundAccountIndex = 0;
            _step = _FindAccountStep.result;
          });
        } else {
          _goToFindAccountNotFound();
        }
      } else {
        final identifier = _passwordEmailController.text.trim();
        final name = _passwordNameController.text.trim();
        final phone = _phoneNumber;

        final forgot = await AuthRepository.forgotPassword(
          name: name,
          phone: phone,
          identifier: identifier,
          otpToken: token,
        );
        if (!mounted) return;

        if (forgot['success'] == true) {
          final root = forgot['data'];
          Map<String, dynamic>? account;
          if (root is Map && root['account'] is Map) {
            account = Map<String, dynamic>.from(root['account'] as Map);
          }
          final rawAccEmail = account?['email']?.toString().trim() ?? '';
          final accountEmail = rawAccEmail.isNotEmpty ? rawAccEmail : identifier;

          if (!mounted) return;
          Navigator.pushNamed(
            context,
            '/find-password-reset',
            arguments: {
              'identifier': identifier,
              'email': accountEmail,
              'name': name,
              'phone': phone,
              'otpToken': token,
              'cert_completed': true,
            },
          );
        } else {
          final code = forgot['code']?.toString();
          if (code == 'PASSWORD_RESET_REQUIRES_CERT') {
            setState(() {
              _emailLookupErrorText = null;
              _verificationErrorText = null;
              _isPhoneCertExpanded = true;
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  forgot['error']?.toString() ??
                      '본인인증이 등록된 계정입니다. 아래 본인인증으로 진행해 주세요.',
                ),
              ),
            );
            return;
          }
          if (forgot['error']?.toString().contains('일치') == true ||
              forgot['error']?.toString().contains('찾을 수 없') == true) {
            _goToFindAccountNotFound({
              'mode': 'password',
              'email': identifier,
              'name': name,
              'phone': phone,
            });
            return;
          }
          setState(() {
            _emailLookupErrorText = forgot['error']?.toString() ??
                '등록된 정보와 일치하는 계정을 찾을 수 없습니다.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificationErrorText = '처리 중 오류가 발생했습니다: $e';
      });
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
      appBar: const HealthAppBar(title: '아이디/비밀번호찾기'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_step == _FindAccountStep.form) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '회원가입 시 등록한 정보를 입력해 주세요',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -1.44,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '소셜 로그인 계정은 각 플랫폼의 계정 찾기 기능을 이용해 주세요.',
                                style: TextStyle(
                                  color: Color(0xFF898686),
                                  fontSize: 12,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: -1.08,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildTabSelector(),
                        const SizedBox(height: 20),
                        _buildActiveForm(),
                        const SizedBox(height: 20),
                        _buildPhoneCertCard(),
                        const SizedBox(height: 16),
                        const SizedBox.shrink(),
                      ] else ...[
                        _buildFindIdResultView(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_step == _FindAccountStep.form)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading || !_canSubmit ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _canSubmit
                          ? const Color(0xFFFF5A8D)
                          : const Color(0xFFD2D2D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '다음',
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
    );
  }

  Widget _buildTabSelector() {
    final isIdTab = _selectedTab == _FindAccountTab.id;
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: const Color(0xFFF9F9F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: '아이디 찾기',
              selected: isIdTab,
              onTap: () {
                _resetForTab(_FindAccountTab.id);
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: '비밀번호 찾기',
              selected: !isIdTab,
              onTap: () {
                _resetForTab(_FindAccountTab.password);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: selected
            ? ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 0.5, color: Color(0x7F898686)),
                  borderRadius: BorderRadius.circular(20),
                ),
              )
            : const ShapeDecoration(shape: RoundedRectangleBorder()),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF898686),
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveForm() {
    if (_selectedTab == _FindAccountTab.id) {
      return Form(
        key: _idFormKey,
        child: Column(
          children: [
            _buildMethodCard(
              title: '등록된 휴대폰으로 찾기',
              child: Column(
                children: [
                  _buildFieldLabel('이름'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _idNameController,
                    hintText: '이름을 입력해 주세요',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름을 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildFieldLabel('휴대폰 번호'),
                  const SizedBox(height: 10),
                  _buildPhoneSection(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '가입 이메일을 입력해 주세요.',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildEmailFieldWithError(),
          _buildMethodCard(
            title: '등록된 휴대폰으로 찾기',
            child: Column(
              children: [
                _buildFieldLabel('이름'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _passwordNameController,
                  hintText: '이름을 입력해 주세요',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해 주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _buildFieldLabel('휴대폰 번호'),
                const SizedBox(height: 10),
                _buildPhoneSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isRegisteredPhoneExpanded = !_isRegisteredPhoneExpanded;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _isRegisteredPhoneExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFD2D2D2),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _isRegisteredPhoneExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                child,
                _buildVerificationField(),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    ));
  }

  Widget _buildEmailFieldWithError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _passwordEmailController,
          hintText: '가입 이메일',
          keyboardType: TextInputType.emailAddress,
          hasError: _emailLookupErrorText != null,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '가입 이메일을 입력해 주세요.';
            }
            return null;
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: _emailLookupErrorText == null
              ? const SizedBox(height: 10)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      _emailLookupErrorText!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool hasError = false,
  }) {
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: _handleFieldChanged,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 14,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              width: 1,
              color: hasError ? const Color(0xFFEF4444) : const Color(0xFFD2D2D2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              width: 1,
              color: hasError ? const Color(0xFFEF4444) : const Color(0xFFD2D2D2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              width: 1,
              color: hasError ? const Color(0xFFEF4444) : const Color(0xFFFF5A8D),
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFEF4444)),
          ),
          errorStyle: const TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 10,
            fontFamily: 'Gmarket Sans TTF',
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildFixedPhoneBox('010')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7),
                    child: SizedBox(
                      width: 8,
                      child: Divider(color: Color(0xFFD9D9D9), thickness: 1),
                    ),
                  ),
                  Expanded(
                    child: _buildPhoneInput(
                      controller: _phoneMidController,
                      maxLength: 4,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7),
                    child: SizedBox(
                      width: 8,
                      child: Divider(color: Color(0xFFD9D9D9), thickness: 1),
                    ),
                  ),
                  Expanded(
                    child: _buildPhoneInput(
                      controller: _phoneLastController,
                      maxLength: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              height: 40,
              child: ElevatedButton(
                onPressed: (_isLoading || _resendCooldownSeconds > 0)
                    ? null
                    : () => _handleSendCode(),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFFF5A8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  '발송',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: _phoneInlineErrorText == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      _phoneInlineErrorText!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFixedPhoneBox(String value) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPhoneInput({
    required TextEditingController controller,
    required int maxLength,
  }) {
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        onChanged: _handleFieldChanged,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(width: 1, color: Color(0xFFFF5A8D)),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationField() {
    if (!_isCodeSent && !_isCodeExpired) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildFieldLabel('인증번호'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextFormField(
                  controller: _verificationCodeController,
                  keyboardType: TextInputType.number,
                  enabled: _isCodeSent && !_isCodeExpired,
                  onChanged: _handleFieldChanged,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                  validator: (value) {
                    if (!_isCodeSent || _isCodeExpired) {
                      return '인증번호를 다시 발송해 주세요.';
                    }
                    if (value == null || value.trim().isEmpty) {
                      return '인증번호를 입력해 주세요.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '인증번호 6자리를 입력해 주세요',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        width: 1,
                        color: _verificationErrorText != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFD2D2D2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        width: 1,
                        color: _verificationErrorText != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFD2D2D2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        width: 1,
                        color: _verificationErrorText != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFFF5A8D),
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(width: 1, color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(width: 1, color: Color(0xFFEF4444)),
                    ),
                    errorStyle: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Color(0xFFFF5A8D),
                ),
                const SizedBox(width: 2),
                Text(
                  _remainingTimeText,
                  style: const TextStyle(
                    color: Color(0xFFFF5A8D),
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_verificationInfoText != null &&
                  _verificationInfoText!.trim().isNotEmpty &&
                  _verificationErrorText == null) ...[
                const SizedBox(height: 10),
                Text(
                  _verificationInfoText!,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (_verificationErrorText != null &&
                  _verificationErrorText!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _verificationErrorText!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneCertCard() {
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isPhoneCertExpanded = !_isPhoneCertExpanded;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '휴대폰 본인인증으로 찾기',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _isPhoneCertExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFD2D2D2),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _isPhoneCertExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                const Text(
                  '본인 명의의 휴대폰으로 인증이 가능합니다.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.08,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 43,
                  child: ElevatedButton(
                    onPressed: _handlePhoneCertNavigation,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFFF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '본인인증 바로가기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    ));
  }

  Widget _buildFindIdResultView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RegisteredAccountList(
          accounts: _foundAccounts,
          selectedIndex: _selectedFoundAccountIndex,
          onSelect: (i) => setState(() => _selectedFoundAccountIndex = i),
        ),
        const SizedBox(height: 20),
        FindAccountResultActions(
          onPasswordFind: () {
            if (_foundAccounts.isEmpty) return;
            final i = _selectedFoundAccountIndex.clamp(0, _foundAccounts.length - 1);
            _resetForTab(
              _FindAccountTab.password,
              prefillPasswordEmail: _foundAccounts[i],
            );
          },
          onLogin: () {
            if (_foundAccounts.isEmpty) {
              Navigator.pushReplacementNamed(context, '/login');
              return;
            }
            final i = _selectedFoundAccountIndex
                .clamp(0, _foundAccounts.length - 1);
            Navigator.pushReplacementNamed(
              context,
              '/login',
              arguments: {'prefillEmail': _foundAccounts[i]},
            );
          },
        ),
      ],
    );
  }

  // _buildMessageArea(): 요구사항에 의해 제거됨
}
