import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/user/user_model.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/last_login_via_service.dart';
import '../../../data/services/pending_product_checkout.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

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

  final _hp1Focus = FocusNode();
  final _hp2Focus = FocusNode();
  final _hp3Focus = FocusNode();
  final _emailFocus = FocusNode();

  bool _terms = true;
  bool _privacy = true;
  bool _marketing = false;
  bool _appPush = false;
  bool _isLoading = false;
  String? _errorText;

  bool get _isNaver => widget.provider.toLowerCase() == 'naver';
  bool get _isApple => widget.provider.toLowerCase() == 'apple';
  bool get _showEmailField =>
      _isNaver || _isApple || (widget.email == null || widget.email!.trim().isEmpty);

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
    _hp1Focus.dispose();
    _hp2Focus.dispose();
    _hp3Focus.dispose();
    _emailFocus.dispose();
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
      identityToken: widget.identityToken,
      authorizationCode: widget.authorizationCode,
      agreements: {
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
          .pushNamedAndRemoveUntil('/enter-home', (route) => false);
      return;
    }

    setState(() {
      _isLoading = false;
      _errorText = result['error']?.toString() ?? '회원가입에 실패했습니다.';
    });
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
        titleFontSize: healthSp(context, 16),
        leadingIconSize: healthDp(context, 24),
      ),
      child: SafeArea(
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
    );
  }

  Widget _buildPhoneRow() {
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
          hint: '1234',
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
          hint: '5678',
        ),
      ],
    );
  }
}
