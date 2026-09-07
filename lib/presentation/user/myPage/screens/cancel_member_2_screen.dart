import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import 'cancel_member_done_screen.dart';

class Cancel2MemberScreen extends StatefulWidget {
  const Cancel2MemberScreen({super.key});

  @override
  State<Cancel2MemberScreen> createState() => _Cancel2MemberScreenState();
}

class _Cancel2MemberScreenState extends State<Cancel2MemberScreen> {
  final TextEditingController _etcController = TextEditingController();
  int? _selectedIndex;

  final List<String> _reasons = const [
    '서비스 이용이 불편해요',
    '원하는 상품/서비스가 없어요',
    '혜택이 적어요',
    '다른 서비스를 이용할 예정이에요',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _etcController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _etcController.dispose();
    super.dispose();
  }

  bool get _isEtcSelected => _selectedIndex == _reasons.length - 1;

  bool get _canWithdraw {
    if (_selectedIndex == null) return false;
    if (_isEtcSelected && _etcController.text.trim().isEmpty) return false;
    return true;
  }

  void _onWithdraw() {
    if (!_canWithdraw) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CancelMemberDoneScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '회원 탈퇴',
        titleFontSize: healthSp(context, 16),
        leadingIconSize: healthDp(context, 24),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 10),
                  healthDp(context, 20),
                  healthDp(context, 20),
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
                    height: 1,
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
                    height: 1.2,
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
                        hintText: '기타 의견을 입력해주세요.',
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
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 10),
                  healthDp(context, 20),
                  healthDp(context, 10),
                ),
                child: Row(
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
                          onPressed: _canWithdraw ? _onWithdraw : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A8D),
                            disabledBackgroundColor: const Color(0xFFD2D2D2),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '탈퇴하기',
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
              ),
            ),
          ],
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
                  fontSize: healthSp(context, 14),
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
