import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: healthDp(context, 64),
                      height: healthDp(context, 64),
                      decoration: ShapeDecoration(
                        color: const Color(0x19FF5C8F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.error_outline,
                        color: const Color(0xFFFF5A8D),
                        size: healthDp(context, 30),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Text(
                      '회원 탈퇴 전 확인해 주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 18),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.78,
                      ),
                    ),
                    Text(
                      '탈퇴 시 아래의 혜택들이 사라집니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 14)),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'COUPONS',
                        valueText: _isLoadingStats ? '...' : '$_couponCount',
                        unitText: '장',
                      ),
                    ),
                    SizedBox(width: healthDp(context, 16)),
                    Expanded(
                      child: _MetricCard(
                        title: 'MY POINTS',
                        valueText: _isLoadingStats
                            ? '...'
                            : PointService.formatPoint(_pointBalance),
                        unitText: 'P',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 14)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(healthDp(context, 16)),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 8)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        AppAssets.cancelIcon1,
                        width: healthDp(context, 16),
                        height: healthDp(context, 15),
                      ),
                      SizedBox(width: healthDp(context, 12)),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '탈퇴 시 보유하신 포인트와 쿠폰이 모두 소멸되며, ',
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1E),
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: '재가입 시에도 복구되지 않습니다.',
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1E),
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                  height: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                InkWell(
                  onTap: () => setState(() => _agreed = !_agreed),
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: healthDp(context, 20),
                        height: healthDp(context, 20),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: healthDp(context, 1),
                              color: _agreed
                                  ? const Color(0xFFFF5A8D)
                                  : const Color(0xFFD2D2D2),
                            ),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 4)),
                          ),
                        ),
                        child: _agreed
                            ? Icon(
                                Icons.check,
                                size: healthDp(context, 16),
                                color: const Color(0xFFFF5A8D),
                              )
                            : null,
                      ),
                      SizedBox(width: healthDp(context, 10)),
                      Expanded(
                        child: Text(
                          '위 유의사항을 모두 확인하였으며, 이에 동의합니다. (필수)',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                            '취소',
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
                          onPressed: _agreed ? _onNextStep : null,
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
                            '다음 단계',
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
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: ShapeDecoration(
        color: const Color(0x0CFF5C8F),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x19FF5C8F),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1.33,
              letterSpacing: healthSp(context, 0.60),
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueText,
                style: TextStyle(
                  color: const Color(0xFFFF5C8F),
                  fontSize: healthSp(context, 20),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  height: 1.60,
                ),
              ),
              SizedBox(width: healthDp(context, 4)),
              Text(
                unitText,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 12),
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
