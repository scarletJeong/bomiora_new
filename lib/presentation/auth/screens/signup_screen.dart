import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/node_value_parser.dart';
import '../../../core/validation/app_password_validator.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/pending_product_checkout.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_alert_dialog.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widgets/agreement_widget.dart';
import '../widgets/kcp_cert.dart';

enum _SignupStep { form, agreement }

class SignupScreen extends StatefulWidget {
  final Map<String, dynamic>? certInfo;

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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordConfirmFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  _SignupStep _step = _SignupStep.form;
  String? _emailErrorText;
  String? _emailSuccessText;
  String? _verifiedEmail;
  bool _isCheckingEmail = false;
  int _emailCheckSeq = 0;

  String? _certName;
  String? _certPhone;
  String? _certBirthday;
  String? _certGender;
  Map<String, dynamic> _rawCertInfo = {};

  bool get _hasCert =>
      (_certName?.trim().isNotEmpty ?? false) &&
      (_certPhone?.trim().isNotEmpty ?? false) &&
      (_certBirthday?.trim().isNotEmpty ?? false) &&
      (_certGender?.trim().isNotEmpty ?? false);

  bool get _hasConfirmMismatch =>
      _passwordConfirmController.text.isNotEmpty &&
      _passwordConfirmController.text != _passwordController.text;

  bool get _isEmailVerified {
    final email = _emailController.text.trim().toLowerCase();
    return _verifiedEmail != null && _verifiedEmail == email;
  }

  bool get _canCheckEmail {
    if (_isLoading || _isCheckingEmail || _isEmailVerified) return false;
    return _isValidEmailFormat(_emailController.text.trim());
  }

  bool get _canInputComplete {
    if (_isLoading || !_hasCert || !_isEmailVerified) return false;
    return _passwordController.text.isNotEmpty &&
        _passwordConfirmController.text.isNotEmpty;
  }

  bool _isDuplicateEmailMessage(String? message) {
    if (message == null) return false;
    return message.contains('이미 존재하는 이메일') || message.contains('이미 있는 아이디');
  }

  bool _isDuplicateCertMessage(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return message.contains('이미 가입') ||
        message.contains('이미 등록된') ||
        message.contains('중복 가입') ||
        message.contains('mb_dupinfo') ||
        m.contains('dupinfo') ||
        m.contains('duplicate');
  }

  @override
  void initState() {
    super.initState();
    void onFieldChanged() {
      if (!mounted) return;
      setState(() {});
    }

    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(onFieldChanged);
    _passwordConfirmController.addListener(onFieldChanged);

    final initial = widget.certInfo;
    if (initial != null && initial.isNotEmpty) {
      _applyCertFromMap(initial);
    } else {
      _rawCertInfo = {};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCertOverlay();
      });
    }
  }

  void _applyCertFromMap(Map<String, dynamic> source) {
    _rawCertInfo = Map<String, dynamic>.from(source);
    _certName = _readString(source, [
      'name',
      'user_name',
      'mem_name',
      'userName',
    ]);
    _certPhone = _normalizePhone(
      _readString(source, [
        'phone',
        'phone_no',
        'phoneNo',
        'mobile_no',
        'mobileNo',
        'tel_no',
      ]),
    );
    _certBirthday = _normalizeBirthday(
      _readString(source, [
        'birthday',
        'birth',
        'birth_day',
        'birthDay',
      ]),
    );
    _certGender = _normalizeGender(
      _readString(source, [
        'gender',
        'sex',
        'sex_code',
        'sexCode',
      ]),
    );
  }

  Future<void> _openCertOverlay() async {
    final cert = await Navigator.push<Map<String, dynamic>?>(
      context,
      PageRouteBuilder<Map<String, dynamic>?>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: const Color(0x991A1A1A),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const KcpCertWebViewScreen(
            flow: 'signup',
            popResultToParent: true,
          );
        },
      ),
    );

    if (!mounted) return;

    if (cert == null) {
      setState(() {
        _rawCertInfo = {};
        _certName = null;
        _certPhone = null;
        _certBirthday = null;
        _certGender = null;
      });
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (cert['popupBlocked'] == true) {
      setState(() {
        _rawCertInfo = {};
        _certName = null;
        _certPhone = null;
        _certBirthday = null;
        _certGender = null;
      });
      return;
    }

    if (cert['duplicate'] == true) {
      await AppAlertDialog.showAlreadyRegisteredThenLogin(context);
      return;
    }

    if (cert['cert_completed'] == true) {
      setState(() => _applyCertFromMap(cert));
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _passwordConfirmFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  bool _isValidEmailFormat(String email) {
    return RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
  }

  void _onEmailChanged() {
    if (!mounted) return;
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      if (_verifiedEmail != null && _verifiedEmail != email) {
        _verifiedEmail = null;
        _emailSuccessText = null;
        _passwordController.clear();
        _passwordConfirmController.clear();
      }
      if (_emailErrorText != null) {
        _emailErrorText = null;
      }
    });
  }

  Future<void> _checkEmailDuplicate() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailErrorText = '이메일을 입력해주세요.';
        _emailSuccessText = null;
        _verifiedEmail = null;
      });
      return;
    }
    if (!_isValidEmailFormat(email)) {
      setState(() {
        _emailErrorText = '올바른 이메일 형식을 입력해주세요.';
        _emailSuccessText = null;
        _verifiedEmail = null;
      });
      return;
    }

    final seq = ++_emailCheckSeq;
    setState(() {
      _isCheckingEmail = true;
      _emailErrorText = null;
      _emailSuccessText = null;
    });

    final result = await AuthRepository.checkEmail(email: email.toLowerCase());
    if (!mounted || seq != _emailCheckSeq) return;

    setState(() {
      _isCheckingEmail = false;
      if (result['exists'] == true) {
        _emailErrorText = '이미 있는 아이디입니다. 다른 아이디를 입력해 주세요.';
        _emailSuccessText = null;
        _verifiedEmail = null;
        return;
      }
      if (result['success'] != true) {
        _emailErrorText =
            (result['error'] ?? '아이디 확인 중 오류가 발생했습니다.').toString();
        _emailSuccessText = null;
        _verifiedEmail = null;
        return;
      }
      _emailErrorText = null;
      _emailSuccessText = '사용 가능한 아이디입니다.';
      _verifiedEmail = email.toLowerCase();
    });

    if (_isEmailVerified && mounted) {
      _passwordFocus.requestFocus();
    }
  }

  String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  String? _normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _normalizeBirthday(String? birthday) {
    if (birthday == null || birthday.isEmpty) return null;
    return birthday.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _normalizeGender(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toUpperCase();
    if (normalized == 'M' ||
        normalized == 'MALE' ||
        normalized == '1' ||
        normalized == '01') {
      return 'M';
    }
    if (normalized == 'F' ||
        normalized == 'FEMALE' ||
        normalized == '2' ||
        normalized == '02') {
      return 'F';
    }
    return null;
  }

  List<String> _phoneSegments(String? phone) {
    final digits = _normalizePhone(phone) ?? '';
    if (digits.length == 11) {
      return [
        digits.substring(0, 3),
        digits.substring(3, 7),
        digits.substring(7)
      ];
    }
    return [digits, '', ''];
  }

  String _formatBirthday(String? birthday) {
    final digits = _normalizeBirthday(birthday);
    if (digits == null || digits.length != 8) return digits ?? '';
    return digits;
  }

  Future<void> _handleInputComplete() async {
    FocusScope.of(context).unfocus();

    if (_certName == null ||
        _certPhone == null ||
        _certBirthday == null ||
        _certGender == null) {
      return;
    }

    if (!_isEmailVerified) {
      AppToastOverlay.show(context, '아이디 중복확인을 해 주세요.');
      return;
    }

    if (!isValidAppPassword(_passwordController.text)) {
      AppToastOverlay.show(context, '비밀번호를 다시 입력해 주세요.');
      return;
    }

    if (_passwordConfirmController.text.isEmpty || _hasConfirmMismatch) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      setState(() {
        _step = _SignupStep.agreement;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAgreementNext(Map<String, bool> agreements) async {
    if (_certName == null || _certPhone == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthRepository.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _certName!,
        phone: _certPhone,
        birthday: _certBirthday,
        gender: _certGender,
        agreements: agreements,
        certInfo: _rawCertInfo,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final resultData = result['data'];
        final dataMap = resultData is Map<String, dynamic>
            ? NodeValueParser.normalizeMap(
                Map<String, dynamic>.from(resultData))
            : <String, dynamic>{};
        final userRaw = dataMap['user'];
        final userJson = NodeValueParser.normalizeMap(
          userRaw is Map
              ? Map<String, dynamic>.from(userRaw)
              : <String, dynamic>{},
        );
        final userId = NodeValueParser.asString(userJson['mb_id']) ??
            NodeValueParser.asString(userJson['id']) ??
            '';
        userJson['id'] = userId;
        userJson['password'] = _passwordController.text;

        final user = UserModel.fromJson(userJson);
        final token = NodeValueParser.asString(dataMap['token']);
        await AuthService.saveLoginData(user: user, token: token);

        if (!mounted) return;
        if (PendingProductCheckout.navigateAfterAuth(context)) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signup-done',
          (route) => false,
        );
      } else {
        final errorMessage = result['error']?.toString() ?? '회원가입에 실패했습니다.';
        if (_isDuplicateEmailMessage(errorMessage) ||
            _isDuplicateCertMessage(errorMessage)) {
          await AppAlertDialog.showAlreadyRegisteredThenLogin(context);
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ [SIGNUP] 회원가입 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleBack() {
    if (_step == _SignupStep.agreement) {
      setState(() {
        _step = _SignupStep.form;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

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
              title: '회원가입',
              onBack: _handleBack,
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  0,
                  healthDp(context, 20),
                  healthDp(context, 20),
                ),
                child: switch (_step) {
                  _SignupStep.form => _buildFormStep(),
                  _SignupStep.agreement => AgreementWidget(
                      isLoading: _isLoading,
                      onNext: _handleAgreementNext,
                    ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    if (!_hasCert) {
      return Center(
        child: SizedBox(
          width: healthDp(context, 36),
          height: healthDp(context, 36),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final phone = _phoneSegments(_certPhone);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        '회원정보를 입력해주세요.\n만 14세 미만은 가입이 불가합니다.',
                        style: TextStyle(
                          color: Color(0xFF898686),
                          fontSize: healthSp(context, 16),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          letterSpacing: healthSp(context, -1.44),
                          height: 1,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 30)),
                      _SignupTextField(
                        label: '아이디(이메일)',
                        controller: _emailController,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_canCheckEmail) _checkEmailDuplicate();
                        },
                        hintText: '이메일을 입력해주세요',
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9@._\-+]'),
                          ),
                        ],
                        hasError: _emailErrorText != null,
                        errorText: _emailErrorText,
                        helperText: _emailSuccessText,
                        helperColor: const Color(0xFF16A34A),
                        trailing: SizedBox(
                          width: healthDp(context, 76),
                          height: healthDp(context, 40),
                          child: ElevatedButton(
                            onPressed:
                                _canCheckEmail ? _checkEmailDuplicate : null,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: _canCheckEmail
                                  ? const Color(0xFFFF5A8D)
                                  : const Color(0xFFD2D2D2),
                              disabledBackgroundColor: const Color(0xFFD2D2D2),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  healthDp(context, 10),
                                ),
                              ),
                            ),
                            child: _isCheckingEmail
                                ? SizedBox(
                                    width: healthDp(context, 16),
                                    height: healthDp(context, 16),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    '중복확인',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: healthSp(context, 13),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '이메일을 입력해주세요.';
                          }
                          if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$')
                              .hasMatch(value.trim())) {
                            return '올바른 이메일 형식을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      if (_isEmailVerified) ...[
                        SizedBox(height: healthDp(context, 10)),
                        _SignupTextField(
                          label: '비밀번호',
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _passwordConfirmFocus.requestFocus(),
                          hintText: '비밀번호를 입력해주세요',
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints(
                              minWidth: healthDp(context, 40),
                              minHeight: healthDp(context, 40),
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF898686),
                              size: healthDp(context, 20),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해주세요.';
                            }
                            if (!isValidAppPassword(value)) {
                              return '8~16자/문자,숫자,특수문자를 모두 포함해주세요.';
                            }
                            return null;
                          },
                          helperText: '*8~16자/문자,숫자,특수문자 모두 혼용',
                        ),
                        SizedBox(height: healthDp(context, 10)),
                        _SignupTextField(
                          label: '비밀번호 확인',
                          controller: _passwordConfirmController,
                          focusNode: _passwordConfirmFocus,
                          textInputAction: TextInputAction.done,
                          hintText: '비밀번호를 다시 입력해주세요',
                          obscureText: _obscurePasswordConfirm,
                          hasError: _hasConfirmMismatch,
                          errorText:
                              _hasConfirmMismatch ? '비밀번호가 일치하지 않습니다.' : null,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePasswordConfirm =
                                    !_obscurePasswordConfirm;
                              });
                            },
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints(
                              minWidth: healthDp(context, 40),
                              minHeight: healthDp(context, 40),
                            ),
                            icon: Icon(
                              _obscurePasswordConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF898686),
                              size: healthDp(context, 20),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호 확인을 입력해주세요.';
                            }
                            if (value != _passwordController.text) {
                              return '비밀번호가 일치하지 않습니다.';
                            }
                            return null;
                          },
                        ),
                      ],
                      SizedBox(height: healthDp(context, 10)),
                      _PhoneReadonlyField(segments: phone),
                      SizedBox(height: healthDp(context, 10)),
                      _ReadonlyField(
                        label: '생년월일',
                        value: _formatBirthday(_certBirthday),
                      ),
                      SizedBox(height: healthDp(context, 10)),
                      _GenderReadonlyField(gender: _certGender),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        SizedBox(
          width: double.infinity,
          height: healthDp(context, 40),
          child: ElevatedButton(
            onPressed: _canInputComplete ? _handleInputComplete : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _canInputComplete
                  ? const Color(0xFFFF5A8D)
                  : const Color(0xFFD2D2D2),
              disabledBackgroundColor: const Color(0xFFD2D2D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
              ),
            ),
            child: Text(
              '입력완료',
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
    );
  }
}

class _SignupTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final Widget? suffix;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool hasError;
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? trailing;
  final Color? helperColor;

  const _SignupTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.suffix,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.hasError = false,
    this.errorText,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.trailing,
    this.helperColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        SizedBox(
          height: healthDp(context, 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  onFieldSubmitted: onFieldSubmitted,
                  inputFormatters: inputFormatters,
                  obscureText: obscureText,
                  expands: !obscureText,
                  minLines: obscureText ? 1 : null,
                  maxLines: obscureText ? 1 : null,
                  validator: validator,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Color(0xFFB8B8B8),
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
                    constraints: BoxConstraints.tightFor(
                      height: healthDp(context, 40),
                    ),
                    suffixIcon: suffix,
                    suffixIconConstraints: BoxConstraints(
                      minWidth: healthDp(context, 40),
                      minHeight: healthDp(context, 40),
                      maxWidth: healthDp(context, 40),
                      maxHeight: healthDp(context, 40),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                      borderSide: BorderSide(
                        width: healthDp(context, 1),
                        color: hasError
                            ? const Color(0xFFFF5A8D)
                            : const Color(0xFFD2D2D2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                      borderSide: BorderSide(
                        width: healthDp(context, 1),
                        color: const Color(0xFFFF5A8D),
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                      borderSide: BorderSide(
                        width: healthDp(context, 1),
                        color: const Color(0xFFFF5A8D),
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                      borderSide: BorderSide(
                        width: healthDp(context, 1),
                        color: const Color(0xFFFF5A8D),
                      ),
                    ),
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: healthDp(context, 8)),
                trailing!,
              ],
            ],
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: healthDp(context, 2)),
          Text(
            errorText!,
            style: TextStyle(
              color: Color(0xFFFF5A8D),
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
        if (helperText != null) ...[
          SizedBox(height: healthDp(context, 2)),
          Text(
            helperText!,
            style: TextStyle(
              color: helperColor ?? const Color(0xFF898686),
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(
          width: double.infinity,
          height: healthDp(context, 40),
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          alignment: Alignment.centerLeft,
          decoration: ShapeDecoration(
            color: const Color(0xFFF5F5F5),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0xFFD2D2D2),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: Color(0xFF898686),
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneReadonlyField extends StatelessWidget {
  final List<String> segments;

  const _PhoneReadonlyField({
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '휴대폰 번호',
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Row(
          children: [
            Expanded(child: _PhoneBox(text: segments[0])),
            SizedBox(width: healthDp(context, 7)),
            const _PhoneDivider(),
            SizedBox(width: healthDp(context, 7)),
            Expanded(child: _PhoneBox(text: segments[1])),
            SizedBox(width: healthDp(context, 7)),
            const _PhoneDivider(),
            SizedBox(width: healthDp(context, 7)),
            Expanded(child: _PhoneBox(text: segments[2])),
          ],
        ),
      ],
    );
  }
}

class _PhoneBox extends StatelessWidget {
  final String text;

  const _PhoneBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: healthDp(context, 40),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Color(0xFF898686),
          fontSize: healthSp(context, 16),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PhoneDivider extends StatelessWidget {
  const _PhoneDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: healthDp(context, 15),
      height: healthDp(context, 1),
      color: const Color(0xFFD9D9D9),
    );
  }
}

class _GenderReadonlyField extends StatelessWidget {
  final String? gender;

  const _GenderReadonlyField({
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = gender == 'M';
    final isFemale = gender == 'F';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '성별',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Row(
          children: [
            Expanded(
              child: _GenderOption(
                label: '여',
                selected: isFemale,
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: _GenderOption(
                label: '남',
                selected: isMale,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;

  const _GenderOption({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: healthDp(context, 40),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: selected ? const Color(0x0CFF5A8D) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: selected ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFFFF5A8D) : const Color(0xFF898383),
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
