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
  /// 비밀번호 찾기 탭 진입 시 이메일(아이디) 자동 입력
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

  String? _errorText;
  String? _resultText;
  String? _emailLookupErrorText;
  String? _verificationErrorText;
  /// 휴대폰 번호 행 바로 아래 표시(발송 전 검증, 인증 만료 등). 분홍 박스 미사용.
  String? _phoneInlineErrorText;
  List<String> _foundAccounts = [];
  int _selectedFoundAccountIndex = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _idNameController.dispose();
    _passwordEmailController.dispose();
    _passwordNameController.dispose();
    _phoneMidController.dispose();
    _phoneLastController.dispose();
    _verificationCodeController.dispose();
    _countdownTimer?.cancel();
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
    _errorText = null;
    _resultText = null;
    _emailLookupErrorText = null;
    _verificationErrorText = null;
    _phoneInlineErrorText = null;
  }

  void _handleFieldChanged(String _) {
    setState(() {
      _clearMessages();
    });
  }

  void _resetForTab(_FindAccountTab tab, {String? prefillPasswordEmail}) {
    _countdownTimer?.cancel();
    setState(() {
      _selectedTab = tab;
      _step = _FindAccountStep.form;
      _isRegisteredPhoneExpanded = false;
      _isPhoneCertExpanded = false;
      _isCodeSent = false;
      _isCodeExpired = false;
      _remainingSeconds = 0;
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
    _remainingSeconds = 180;
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
          _verificationCodeController.clear();
          _errorText = null;
          _resultText = null;
          _phoneInlineErrorText = '인증시간이 만료되었습니다. 다시 발송해 주세요.';
        });
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  void _handleSendCode() {
    final hasEnoughData = _selectedTab == _FindAccountTab.id
        ? _idNameController.text.trim().isNotEmpty
        : _passwordEmailController.text.trim().isNotEmpty &&
            _passwordNameController.text.trim().isNotEmpty;

    if (!hasEnoughData ||
        _phoneMidController.text.trim().length < 3 ||
        _phoneLastController.text.trim().length < 4) {
      setState(() {
        _errorText = null;
        _phoneInlineErrorText = '이름과 휴대폰 번호를 먼저 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isCodeSent = true;
      _isCodeExpired = false;
      _verificationErrorText = null;
      _resultText = null;
      _errorText = null;
      _phoneInlineErrorText = null;
    });
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
          _emailLookupErrorText = '아이디(이메일)를 입력해 주세요.';
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

    if (_verificationCodeController.text.trim() != '1234') {
      setState(() {
        _verificationErrorText = '인증번호가 일치하지 않습니다.';
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
        final result = await AuthRepository.findId(
          name: _passwordNameController.text.trim(),
          phone: _phoneNumber,
        );

        if (!mounted) return;

        final accounts = parseFindIdAccountEmails(result);
        final email = _passwordEmailController.text.trim();
        final name = _passwordNameController.text.trim();
        final phone = _phoneNumber;

        if (accounts.isEmpty) {
          _goToFindAccountNotFound({
            'mode': 'password',
            'email': email,
            'name': name,
            'phone': phone,
          });
          return;
        } else if (!accounts.contains(email)) {
          setState(() {
            _emailLookupErrorText = '등록된 아이디(이메일)가 없습니다.';
          });
        } else {
          final forgot = await AuthRepository.forgotPassword(
            email: email,
            name: name,
            phone: phone,
          );
          if (!mounted) return;
          if (forgot['success'] == true) {
            Navigator.pushNamed(
              context,
              '/find-password-reset',
              arguments: {
                'email': email,
                'name': name,
                'phone': phone,
                'cert_completed': true,
              },
            );
          } else {
            setState(() {
              _errorText = forgot['error']?.toString() ??
                  '비밀번호 재설정을 진행할 수 없습니다.';
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '처리 중 오류가 발생했습니다: $e';
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
                        _buildMessageArea(),
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
              '아이디(이메일)를 입력해 주세요.',
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
          hintText: '아이디(이메일)',
          keyboardType: TextInputType.emailAddress,
          hasError: _emailLookupErrorText != null,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '아이디(이메일)를 입력해 주세요.';
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
                onPressed: _handleSendCode,
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
                    hintText: '인증번호 4자리를 입력해 주세요',
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
          child: _verificationErrorText == null
              ? const SizedBox(height: 10)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

  Widget _buildMessageArea() {
    if (_errorText == null && _resultText == null) {
      return const SizedBox.shrink();
    }

    final isError = _errorText != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F2) : const Color(0xFFFFF4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? const Color(0xFFEF4444) : const Color(0xFFFF5A8D),
        ),
      ),
      child: Text(
        isError ? _errorText! : _resultText!,
        style: TextStyle(
          color: isError ? const Color(0xFFEF4444) : const Color(0xFFFF5A8D),
          fontSize: 13,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
