import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

class Cancel2MemberScreen extends StatefulWidget {
  const Cancel2MemberScreen({super.key});

  @override
  State<Cancel2MemberScreen> createState() => _Cancel2MemberScreenState();
}

class _Cancel2MemberScreenState extends State<Cancel2MemberScreen> {
  final TextEditingController _etcController = TextEditingController();
  int? _selectedIndex;
  bool _isSubmitting = false;

  final List<String> _reasons = const [
    '서비스 이용이 불편해요',
    '원하는 상품/서비스가 없어요',
    '혜택이 적어요',
    '다른 서비스를 이용할 예정이에요',
    '기타',
  ];

  @override
  void dispose() {
    _etcController.dispose();
    super.dispose();
  }

  bool get _isEtcSelected => _selectedIndex == _reasons.length - 1;

  Future<void> _onWithdraw() async {
    if (_selectedIndex == null || _isSubmitting) return;
    if (_isEtcSelected && _etcController.text.trim().isEmpty) {
      return;
    }

    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      return;
    }

    final reason = _reasons[_selectedIndex!];
    final fullReason = _isEtcSelected
        ? '기타:${_etcController.text.trim()}'
        : reason;

    setState(() => _isSubmitting = true);
    final result = await AuthService.withdrawMember(
      mbId: user.id,
      reason: fullReason,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] != true) {
      return;
    }

    await AuthService.logout();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CancelMemberCompleteScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '회원 탈퇴',
        titleFontSize: healthSp(context, 18),
        leadingIconSize: healthDp(context, 24),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 27),
              vertical: healthDp(context, 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '탈퇴하시는 이유가 궁금해요',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 18),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  '보미오라를 떠나시는 이유를 알려주시면 \n더 나은 서비스로보답하겠습니다',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 14)),
                ...List.generate(_reasons.length, (index) {
                  final selected = _selectedIndex == index;
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context,14)),
                    child: _ReasonTile(
                      title: _reasons[index],
                      selected: selected,
                      onTap: () => setState(() => _selectedIndex = index),
                    ),
                  );
                }),
                if (_isEtcSelected) ...[
                  Container(
                    height: healthDp(context, 120),
                    padding: EdgeInsets.all(healthDp(context, 14)),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: healthDp(context, 1),
                          color: const Color(0xFFD2D2D2),
                        ),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: TextField(
                      controller: _etcController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '기타 의견을 입력해주세요. (선택사항)',
                        hintStyle: TextStyle(
                          color: const Color(0xFF898686),
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: healthDp(context, 48)),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: healthDp(context, 40),
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color(0xFFD2D2D2),
                              width: healthDp(context, 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            '이전',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF898686),
                              fontSize: healthSp(context, 16),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 20)),
                    Expanded(
                      child: SizedBox(
                        height: healthDp(context, 40),
                        child: ElevatedButton(
                          onPressed: (_selectedIndex == null || _isSubmitting)
                              ? null
                              : _onWithdraw,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A8D),
                            disabledBackgroundColor:
                                const Color(0xFFFF5A8D).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _isSubmitting ? '처리중...' : '탈퇴하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: healthSp(context, 16),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Container(
        padding: EdgeInsets.all(healthDp(context, 10)),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: selected
                  ? const Color(0xFFFF5A8D)
                  : const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Row(
          children: [
            _RadioDot(selected: selected),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.50,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final outer = healthDp(context, 24);
    final inner = healthDp(context, 12);

    if (!selected) {
      return Container(
        width: outer,
        height: outer,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 2),
              color: const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(outer),
          ),
        ),
      );
    }

    return Container(
      width: outer,
      height: outer,
      decoration: ShapeDecoration(
        color: const Color(0xFFFF5C8F),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 2),
            color: const Color(0xFFFF5C8F),
          ),
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
    );
  }
}

class CancelMemberCompleteScreen extends StatelessWidget {
  const CancelMemberCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void goHome() {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }

    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '회원 탈퇴',
        titleFontSize: healthSp(context, 18),
        leadingIconSize: healthDp(context, 24),
        onBack: goHome,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            goHome();
          },
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 27),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: healthDp(context, 12)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: healthDp(context, 32),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: healthDp(context, 192),
                        height: healthDp(context, 192),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: ShapeDecoration(
                                  color: const Color(0x0CFF5C8F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: healthDp(context, 16),
                              top: healthDp(context, 16),
                              child: Container(
                                width: healthDp(context, 160),
                                height: healthDp(context, 160),
                                decoration: ShapeDecoration(
                                  color: const Color(0x19FF5C8F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: healthDp(context, 120),
                                height: healthDp(context, 120),
                                child: SvgPicture.asset(
                                  AppAssets.cancelMemberIcon,
                                  width: healthDp(context, 120),
                                  height: healthDp(context, 120),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 14)),
                  Text(
                    '탈퇴가 완료되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 20),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  Text(
                    '그동안 보미오라를 이용해 주셔서 감사합니다.\n더 발전된 모습으로 다시 만날 수 있기를 바랍니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 30)),
                  SizedBox(
                    height: healthDp(context, 40),
                    child: ElevatedButton(
                      onPressed: goHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A8D),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 10)),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '메인으로 이동',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 16),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
