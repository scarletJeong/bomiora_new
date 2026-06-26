import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/user/user_model.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';

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
  });

  @override
  State<SocialSignupScreen> createState() => _SocialSignupScreenState();
}

class _SocialSignupScreenState extends State<SocialSignupScreen> {
  final _hp1 = TextEditingController(text: '010');
  final _hp2 = TextEditingController();
  final _hp3 = TextEditingController();
  late final TextEditingController _emailController;

  bool _terms = true;
  bool _privacy = true;
  bool _isLoading = false;
  String? _errorText;

  bool get _isNaver => widget.provider.toLowerCase() == 'naver';

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
    super.dispose();
  }

  String get _phone =>
      '${_hp1.text.trim()}-${_hp2.text.trim()}-${_hp3.text.trim()}';

  Future<void> _submit() async {
    final phoneDigits = _phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length < 10) {
      setState(() => _errorText = '휴대폰 번호를 올바르게 입력해 주세요.');
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = '이메일을 입력해 주세요.');
      return;
    }

    if (!_terms || !_privacy) {
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
      phone: _phone,
      email: email,
      name: widget.name ?? widget.nickname ?? email.split('@').first,
      nickname: widget.nickname,
      gender: widget.gender,
      birthday: widget.birthday,
      profileImageUrl: widget.profileImageUrl,
      agreements: {
        'terms': _terms,
        'privacy': _privacy,
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

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      return;
    }

    setState(() {
      _isLoading = false;
      _errorText = result['error']?.toString() ?? '회원가입에 실패했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = _isNaver ? '네이버' : '카카오';

    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF1A1A1A),
          title: Text(
            '$providerLabel 회원가입',
            style: TextStyle(
              fontFamily: 'Gmarket Sans TTF',
              fontSize: healthSp(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
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
                if (_isNaver) ...[
                  SizedBox(height: healthDp(context, 20)),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '이메일',
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
                  title: const Text('이용약관 동의 (필수)'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _privacy,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _privacy = v ?? false),
                  title: const Text('개인정보 처리방침 동의 (필수)'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
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
                  onPressed: _isLoading ? null : _submit,
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
        ),
      ),
    );
  }

  Widget _buildPhoneRow() {
    Widget part(TextEditingController c, {int? maxLen, String? hint}) {
      return Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            if (maxLen != null) LengthLimitingTextInputFormatter(maxLen),
          ],
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        part(_hp1, maxLen: 3),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
          child: const Text('-'),
        ),
        part(_hp2, maxLen: 4, hint: '1234'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
          child: const Text('-'),
        ),
        part(_hp3, maxLen: 4, hint: '5678'),
      ],
    );
  }
}
