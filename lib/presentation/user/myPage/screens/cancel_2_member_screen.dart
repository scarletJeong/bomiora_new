import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';

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
      appBar: const HealthAppBar(title: '회원 탈퇴'),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                '탈퇴하시는 이유가 궁금해요',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.60,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '보미오라를 떠나시는 이유를 알려주시면 \n더 나은 서비스로보답하겠습니다',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.67,
                ),
              ),
              const SizedBox(height: 18),
              ...List.generate(_reasons.length, (index) {
                final selected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReasonTile(
                    title: _reasons[index],
                    selected: selected,
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              }),
              if (_isEtcSelected) ...[
                const SizedBox(height: 6),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(15),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: TextField(
                    controller: _etcController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '탈퇴 사유를 입력해 주세요.',
                      hintStyle: TextStyle(
                        color: Color(0xFF898686),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD2D2D2), width: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: Colors.white,
                        ),
                        child: const Text(
                          '이전',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF898686),
                            fontSize: 16,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: (_selectedIndex == null || _isSubmitting) ? null : _onWithdraw,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          disabledBackgroundColor: const Color(0xFFFF5A8D).withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          _isSubmitting ? '처리중...' : '탈퇴하기',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: selected ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            _RadioDot(selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
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
    if (!selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 2, color: Color(0xFFD2D2D2)),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: ShapeDecoration(
        color: const Color(0xFFFF5C8F),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: Color(0xFFFF5C8F)),
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
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
              padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: SizedBox(
                        width: 192,
                        height: 192,
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
                              left: 16,
                              top: 16,
                              child: Container(
                                width: 160,
                                height: 160,
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
                                width: 120,
                                height: 120,
                                child: SvgPicture.asset(
                                  AppAssets.cancelMemberIcon,
                                  width: 120,
                                  height: 120,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '탈퇴가 완료되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.60,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '그동안 보미오라를 이용해 주셔서 감사합니다.\n더 발전된 모습으로 다시 만날 수 있기를 바랍니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.67,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: goHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A8D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '메인으로 이동',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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

