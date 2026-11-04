import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
/// 회원탈퇴 화면
class CancelMemberScreen extends StatefulWidget {
  const CancelMemberScreen({super.key});

  @override
  State<CancelMemberScreen> createState() => _CancelMemberScreenState();
}

class _CancelMemberScreenState extends State<CancelMemberScreen> {
  bool _agreed = false;
  bool _couponLoading = true;
  bool _pointLoading = true;
  bool _couponFailed = false;
  bool _pointFailed = false;
  int _pointBalance = 0;
  int _couponCount = 0;

  bool get _statsReady =>
      !_couponLoading &&
      !_pointLoading &&
      !_couponFailed &&
      !_pointFailed;

  @override
  void initState() {
    super.initState();
    _agreed = false;
    _loadWithdrawStats();
  }

  Future<void> _loadWithdrawStats() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _couponFailed = true;
        _pointFailed = true;
        _couponLoading = false;
        _pointLoading = false;
      });
      return;
    }
    await Future.wait([
      _loadCouponCount(),
      _loadPointBalance(),
    ]);
  }

  Future<void> _loadCouponCount() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _couponFailed = true;
        _couponLoading = false;
      });
      return;
    }
    setState(() => _couponLoading = true);
    try {
      final count = await CouponService.countAvailableCoupons(
        user.id,
        surfaceFailure: true,
      );
      if (!mounted) return;
      setState(() {
        if (count == null) {
          _couponFailed = true;
        } else {
          _couponCount = count;
          _couponFailed = false;
        }
        _couponLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _couponFailed = true;
        _couponLoading = false;
      });
    }
  }

  Future<void> _loadPointBalance() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _pointFailed = true;
        _pointLoading = false;
      });
      return;
    }
    setState(() => _pointLoading = true);
    try {
      final point = await PointService.getUserPoint(user.id);
      if (!mounted) return;
      setState(() {
        if (point == null) {
          _pointFailed = true;
        } else {
          _pointBalance = point;
          _pointFailed = false;
        }
        _pointLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pointFailed = true;
        _pointLoading = false;
      });
    }
  }

  void _onNextStep() {
    if (!_agreed) return;
    Navigator.pushNamed(context, '/withdraw/reason');
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '회원 탈퇴',
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
                    SizedBox(height: healthDp(context, 20)),
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
                        valueText: _couponLoading
                            ? '…'
                            : _couponFailed
                                ? '다시 시도'
                                : '$_couponCount',
                        unitText: _couponFailed ? '' : '장',
                        onTap: _couponFailed ? _loadCouponCount : null,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 16)),
                    Expanded(
                      child: _MetricCard(
                        title: 'MY POINTS',
                        valueText: _pointLoading
                            ? '…'
                            : _pointFailed
                                ? '다시 시도'
                                : PointService.formatPoint(_pointBalance),
                        unitText: _pointFailed ? '' : 'P',
                        onTap: _pointFailed ? _loadPointBalance : null,
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
                SizedBox(height: healthDp(context, 4)),
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
                              color: const Color(0xFFD2D2D2),
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
                          onPressed: _agreed && _statsReady ? _onNextStep : null,
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
              ),
            ),
          ],
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
    this.onTap,
  });

  final String title;
  final String valueText;
  final String unitText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
      ),
    );
  }
}
