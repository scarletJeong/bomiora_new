import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import 'cancel_2_member_screen.dart';

/// 회원탈퇴 화면
class CancelMemberScreen extends StatefulWidget {
  const CancelMemberScreen({super.key});

  @override
  State<CancelMemberScreen> createState() => _CancelMemberScreenState();
}

class _CancelMemberScreenState extends State<CancelMemberScreen> {
  bool _agreed = false;
  bool _isLoadingStats = true;
  int _pointBalance = 0;
  int _couponCount = 0;

  @override
  void initState() {
    super.initState();
    _agreed = false;
    _loadWithdrawStats();
  }

  Future<void> _loadWithdrawStats() async {
    try {
      final user = await AuthService.getUser();
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _pointBalance = 0;
          _couponCount = 0;
          _isLoadingStats = false;
        });
        return;
      }

      final results = await Future.wait([
        PointService.getUserPoint(user.id),
        CouponService.getAvailableCoupons(user.id),
      ]);

      if (!mounted) return;
      final point = results[0] as int?;
      final coupons = results[1] as List<dynamic>;
      setState(() {
        _pointBalance = point ?? 0;
        _couponCount = coupons.length;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pointBalance = 0;
        _couponCount = 0;
        _isLoadingStats = false;
      });
    }
  }

  void _onNextStep() {
    if (!_agreed) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Cancel2MemberScreen(),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: ShapeDecoration(
                      color: const Color(0x19FF5C8F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF5A8D),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '회원 탈퇴 전 확인해 주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.60,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '그동안 서비스를 이용해 주셔서 감사합니다.\n탈퇴 시 아래의 혜택들이 사라집니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.67,
                    ),
                  ),
                ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'MY POINTS',
                        valueText: _isLoadingStats ? '...' : PointService.formatPoint(_pointBalance),
                        unitText: 'P',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: 'COUPONS',
                        valueText: _isLoadingStats ? '...' : '$_couponCount',
                        unitText: '장',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(
                    top: 14.75,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '탈퇴 시 보유하신 ',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 12,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.90,
                          ),
                        ),
                        TextSpan(
                          text: '포인트와 쿠폰이 모두 소멸',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 12,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '되며, 재가입 시에도 복구되지 않습니다.',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 12,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.90,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => setState(() => _agreed = !_agreed),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: ShapeDecoration(
                          color: _agreed ? const Color(0xFFFF5A8D) : Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: 1,
                              color: _agreed ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: _agreed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '위 유의사항을 모두 확인하였으며, 이에 동의합니다. (필수)',
                          style: TextStyle(
                            color: Color(0xFF898686),
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text(
                            '취소',
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
                          onPressed: _agreed ? _onNextStep : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A8D),
                            disabledBackgroundColor: const Color(0xFFFF5A8D).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '다음 단계',
                            style: TextStyle(
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.valueText,
    required this.unitText,
  });

  final String title;
  final String valueText;
  final String unitText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: const Color(0x0CFF5C8F),
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x19FF5C8F),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1.33,
              letterSpacing: 0.60,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueText,
                style: const TextStyle(
                  color: Color(0xFFFF5C8F),
                  fontSize: 20,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  height: 1.60,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unitText,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.67,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

