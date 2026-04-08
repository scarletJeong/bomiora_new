import 'package:flutter/material.dart';

import '../../../core/utils/node_value_parser.dart';
import '../../../core/validation/app_password_validator.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../user/healthprofile/screens/health_profile_list_screen.dart';
import '../widgets/agreement_widget.dart';

enum _SignupStep { form, agreement, complete }

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

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  _SignupStep _step = _SignupStep.form;

  String? _certName;
  String? _certPhone;
  String? _certBirthday;
  String? _certGender;
  Map<String, dynamic> _rawCertInfo = {};

  bool get _canInputComplete {
    if (_isLoading) return false;
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _passwordConfirmController.text.isNotEmpty;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _isDuplicateEmailMessage(String? message) {
    if (message == null) return false;
    return message.contains('이미 존재하는 이메일') || message.contains('이미 있는 아이디');
  }

  @override
  void initState() {
    super.initState();
    void onFieldChanged() {
      if (!mounted) return;
      setState(() {});
    }
    _emailController.addListener(onFieldChanged);
    _passwordController.addListener(onFieldChanged);
    _passwordConfirmController.addListener(onFieldChanged);

    _rawCertInfo = Map<String, dynamic>.from(widget.certInfo ?? <String, dynamic>{});
    _certName = _readString(widget.certInfo, [
      'name',
      'user_name',
      'mem_name',
      'userName',
    ]);
    _certPhone = _normalizePhone(
      _readString(widget.certInfo, [
        'phone',
        'phone_no',
        'phoneNo',
        'mobile_no',
        'mobileNo',
        'tel_no',
      ]),
    );
    _certBirthday = _normalizeBirthday(
      _readString(widget.certInfo, [
        'birthday',
        'birth',
        'birth_day',
        'birthDay',
      ]),
    );
    _certGender = _normalizeGender(
      _readString(widget.certInfo, [
        'gender',
        'sex',
        'sex_code',
        'sexCode',
      ]),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
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
    if (normalized == 'M' || normalized == 'MALE' || normalized == '1' || normalized == '01') {
      return 'M';
    }
    if (normalized == 'F' || normalized == 'FEMALE' || normalized == '2' || normalized == '02') {
      return 'F';
    }
    return null;
  }

  List<String> _phoneSegments(String? phone) {
    final digits = _normalizePhone(phone) ?? '';
    if (digits.length == 11) {
      return [digits.substring(0, 3), digits.substring(3, 7), digits.substring(7)];
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
    if (!_formKey.currentState!.validate()) return;

    if (_certName == null || _certPhone == null || _certBirthday == null || _certGender == null) {
      _showErrorSnackBar('본인인증 정보를 확인한 뒤 다시 진행해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final checkResult = await AuthRepository.checkEmail(email: email);
      if (!mounted) return;

      if (checkResult['success'] != true) {
        _showErrorSnackBar(
          checkResult['error']?.toString() ?? '이메일 중복 확인 중 오류가 발생했습니다.',
        );
        return;
      }

      if (checkResult['exists'] == true) {
        _showErrorSnackBar('이미 있는 아이디입니다.');
        return;
      }

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
            ? NodeValueParser.normalizeMap(Map<String, dynamic>.from(resultData))
            : <String, dynamic>{};
        final userRaw = dataMap['user'];
        final userJson = NodeValueParser.normalizeMap(
          userRaw is Map
              ? Map<String, dynamic>.from(userRaw)
              : <String, dynamic>{},
        );
        final userId =
            NodeValueParser.asString(userJson['mb_id']) ??
            NodeValueParser.asString(userJson['id']) ??
            '';
        userJson['id'] = userId;
        userJson['password'] = _passwordController.text;

        final user = UserModel.fromJson(userJson);
        final token = NodeValueParser.asString(dataMap['token']);
        await AuthService.saveLoginData(user: user, token: token);

        if (!mounted) return;
        setState(() {
          _step = _SignupStep.complete;
        });
      } else {
        final errorMessage = result['error']?.toString() ?? '회원가입에 실패했습니다.';
        if (_isDuplicateEmailMessage(errorMessage)) {
          setState(() {
            _step = _SignupStep.form;
          });
          _showErrorSnackBar('이미 있는 아이디입니다.');
          return;
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ [SIGNUP] 회원가입 오류: $e');
      _showErrorSnackBar('회원가입 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleBack() {
    if (_step == _SignupStep.complete) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      return;
    }
    if (_step == _SignupStep.agreement) {
      setState(() {
        _step = _SignupStep.form;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _goHealthDashboard() {
    Navigator.of(context).pushNamed('/health');
  }

  void _goHealthQuestionnaire() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HealthProfileListScreen()),
    );
  }

  void _goShoppingMall() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: '회원가입',
        onBack: _handleBack,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: switch (_step) {
            _SignupStep.form => _buildFormStep(),
            _SignupStep.agreement => AgreementWidget(
                isLoading: _isLoading,
                onNext: _handleAgreementNext,
              ),
            _SignupStep.complete => _SignupCompleteView(
                onGoHome: _goHome,
                onGoHealthDashboard: _goHealthDashboard,
                onGoHealthQuestionnaire: _goHealthQuestionnaire,
                onGoShoppingMall: _goShoppingMall,
              ),
          },
        ),
      ),
    );
  }

  Widget _buildFormStep() {
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
                      const Text(
                        '환영합니다.',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '회원정보를 입력해주세요.\n만 14세 미만은 가입이 불가합니다.',
                        style: TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.44,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReadonlyField(
                        label: '이름',
                        value: _certName ?? '',
                      ),
                      const SizedBox(height: 10),
                      _ReadonlyField(
                        label: '생년월일',
                        value: _formatBirthday(_certBirthday),
                      ),
                      const SizedBox(height: 10),
                      _GenderReadonlyField(gender: _certGender),
                      const SizedBox(height: 10),
                      _PhoneReadonlyField(segments: phone),
                      const SizedBox(height: 10),
                      _SignupTextField(
                        label: '아이디(이메일)',
                        controller: _emailController,
                        hintText: '이메일을 입력해주세요',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '이메일을 입력해주세요.';
                          }
                          if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value.trim())) {
                            return '올바른 이메일 형식을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _SignupTextField(
                        label: '비밀번호',
                        controller: _passwordController,
                        hintText: '비밀번호를 입력해주세요',
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF898686),
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
                      const SizedBox(height: 10),
                      _SignupTextField(
                        label: '비밀번호 확인',
                        controller: _passwordConfirmController,
                        hintText: '비밀번호를 다시 입력해주세요',
                        obscureText: _obscurePasswordConfirm,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePasswordConfirm = !_obscurePasswordConfirm;
                            });
                          },
                          icon: Icon(
                            _obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF898686),
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
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: _canInputComplete ? _handleInputComplete : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor:
                  _canInputComplete ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
              disabledBackgroundColor: const Color(0xFFD2D2D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '입력완료',
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
  final String? Function(String?)? validator;

  const _SignupTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.suffix,
    this.helperText,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFFB8B8B8),
              fontSize: 14,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            suffixIcon: suffix,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(width: 1, color: Color(0xFFFF5A8D)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(width: 1, color: Color(0xFFE53935)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(width: 1, color: Color(0xFFE53935)),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 2),
          Text(
            helperText!,
            style: const TextStyle(
              color: Color(0xFF898686),
              fontSize: 10,
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
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
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
        const Text(
          '휴대폰 번호',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _PhoneBox(text: segments[0])),
            const SizedBox(width: 7),
            const _PhoneDivider(),
            const SizedBox(width: 7),
            Expanded(child: _PhoneBox(text: segments[1])),
            const SizedBox(width: 7),
            const _PhoneDivider(),
            const SizedBox(width: 7),
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
      height: 40,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
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
      width: 15,
      height: 1,
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
        const Text(
          '성별',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GenderOption(
                label: '여',
                selected: isFemale,
              ),
            ),
            const SizedBox(width: 10),
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
      height: 40,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: selected ? const Color(0x0CFF5A8D) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: selected ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFFFF5A8D) : const Color(0xFF898383),
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SignupCompleteView extends StatelessWidget {
  final VoidCallback onGoHome;
  final VoidCallback onGoHealthDashboard;
  final VoidCallback onGoHealthQuestionnaire;
  final VoidCallback onGoShoppingMall;

  const _SignupCompleteView({
    required this.onGoHome,
    required this.onGoHealthDashboard,
    required this.onGoHealthQuestionnaire,
    required this.onGoShoppingMall,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '회원 가입 완료 !',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '회원가입을 진심으로 축하드립니다.\n보미오라만의 다양한 서비스를 만나보세요.',
                        style: TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _BenefitCard(
                  title: '문진표',
                  subtitle: '나의 건강 상태 확인하기',
                  icon: Icons.assignment_rounded,
                  iconBackground: Color(0xFFEFF6FF),
                  iconColor: Color(0xFF2563EB),
                  onTap: onGoHealthQuestionnaire,
                ),
                const SizedBox(height: 10),
                const _BenefitCard(
                  title: '비대면 진료',
                  subtitle: '집에서 편하게 받는 진료',
                  icon: Icons.medical_services_rounded,
                  iconBackground: Color(0xFFECFDF5),
                  iconColor: Color(0xFF10B981),
                ),
                const SizedBox(height: 10),
                _BenefitCard(
                  title: '쇼핑몰',
                  subtitle: '맞춤 영양제 및 건강 용품',
                  icon: Icons.shopping_bag_rounded,
                  iconBackground: Color(0xFFFFF7ED),
                  iconColor: Color(0xFFF97316),
                  onTap: onGoShoppingMall,
                ),
                const SizedBox(height: 10),
                _BenefitCard(
                  title: '건강 대시보드',
                  subtitle: '나의 건강 데이터를 한눈에',
                  icon: Icons.monitor_heart_rounded,
                  iconBackground: Color(0xFFFAF5FF),
                  iconColor: Color(0xFF9333EA),
                  onTap: onGoHealthDashboard,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: onGoHome,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFFF5A8D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '홈으로 이동',
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
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback? onTap;

  const _BenefitCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                color: iconBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.75,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1.67,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
