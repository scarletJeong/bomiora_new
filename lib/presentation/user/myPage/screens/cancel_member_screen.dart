import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../common/widgets/acknowledge_alert_dialog.dart';
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
  bool _progressLoading = true;
  bool _couponFailed = false;
  bool _pointFailed = false;
  bool _progressFailed = false;
  int _pointBalance = 0;
  int _couponCount = 0;
  int _paymentWaiting = 0;
  int _paid = 0;
  int _preparing = 0;
  int _consultationDone = 0;
  int _ongoingReservation = 0;

  bool get _statsReady =>
      !_couponLoading &&
      !_pointLoading &&
      !_progressLoading &&
      !_couponFailed &&
      !_pointFailed &&
      !_progressFailed;

  List<({String label, int count})> get _progressItems => [
        (label: '결제 대기', count: _paymentWaiting),
        (label: '결제 완료', count: _paid),
        (label: '배송 준비', count: _preparing),
        (label: '상담 내역', count: _consultationDone),
        (label: '진행 중 예약', count: _ongoingReservation),
      ];

  int get _progressTotal =>
      _progressItems.fold<int>(0, (sum, item) => sum + item.count);

  bool get _hasOpenProgress => _progressTotal > 0;

  String get _progressSummary {
    final active = _progressItems.where((item) => item.count > 0);
    if (active.isEmpty) return '0건';
    return active.map((item) => '${item.label} ${item.count}건').join(', ');
  }

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
        _progressFailed = true;
        _couponLoading = false;
        _pointLoading = false;
        _progressLoading = false;
      });
      return;
    }
    await Future.wait([
      _loadCouponCount(),
      _loadPointBalance(),
      _loadWithdrawProgress(),
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

  Future<void> _loadWithdrawProgress() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _progressFailed = true;
        _progressLoading = false;
      });
      return;
    }
    setState(() => _progressLoading = true);
    final result = await AuthService.getWithdrawPending(user.id);
    if (!mounted) return;
    setState(() {
      if (result['success'] != true) {
        _progressFailed = true;
      } else {
        _paymentWaiting = result['paymentWaiting'] as int? ?? 0;
        _paid = result['paid'] as int? ?? 0;
        _preparing = result['preparing'] as int? ?? 0;
        _consultationDone = result['consultationDone'] as int? ?? 0;
        _ongoingReservation = result['ongoingReservation'] as int? ?? 0;
        _progressFailed = false;
      }
      _progressLoading = false;
    });
  }

  Future<void> _onNextStep() async {
    if (!_agreed || !_statsReady) return;
    if (_hasOpenProgress) {
      final proceed = await AcknowledgeAlertDialog.show(
        context,
        title: '정말 탈퇴하시겠어요?',
        message: '탈퇴하면 계정과 아래 정보가 즉시 삭제되며,\n다시 복구할 수 없어요.',
        summaryLabel: '현재 진행 중',
        summaryValue: _progressSummary,
        detail: '진행 중인 결제·예약·상담 내역과 완료한 내역은 탈퇴 후 확인하거나 복구할 수 없습니다.',
      );
      if (!proceed || !mounted) return;
    }
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
                Padding(
                  padding: EdgeInsets.only(
                    bottom: healthDp(context, 12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: healthDp(context, 64),
                        height: healthDp(context, 64),
                        decoration: ShapeDecoration(
                          color: const Color(0x19FF5A8D),
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
                        '탈퇴 전 꼭 확인해 주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFF4F87),
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1.50,
                          letterSpacing: healthSp(context, -0.13),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: healthDp(context, 5)),
                        child: Text(
                          '사라지는 혜택과 내역이 있어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF19191B),
                            fontSize: healthSp(context, 18),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.50,
                            letterSpacing: healthSp(context, -0.96),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: healthDp(context, 0)),
                        child: Text(
                          '탈퇴하면 아래 정보는 즉시 삭제되고 다시 복구할 수 없습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF79797F),
                            fontSize: healthSp(context, 11),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                            height: 1.60,
                            letterSpacing: healthSp(context, -0.38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: healthDp(context, 14)),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: '보유 쿠폰',
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
                        title: '보유 포인트',
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
                _ProgressCard(
                  loading: _progressLoading,
                  failed: _progressFailed,
                  paymentWaiting: _paymentWaiting,
                  paid: _paid,
                  preparing: _preparing,
                  consultationDone: _consultationDone,
                  ongoingReservation: _ongoingReservation,
                  onRetry: _progressFailed ? _loadWithdrawProgress : null,
                ),
                SizedBox(height: healthDp(context, 14)),
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
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.5,
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
                              fontSize: healthSp(context, 14),
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
                            '탈퇴 계속하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: healthSp(context, 14),
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
        color: const Color(0x0CFF5A8D),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x19FF5A8D),
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
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1.33,
              letterSpacing: 0,
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
                  color: const Color(0xFFFF5A8D),
                  fontSize: healthSp(context, 18),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.60,
                ),
              ),
              SizedBox(width: healthDp(context, 4)),
              Text(
                unitText,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 10),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.loading,
    required this.failed,
    required this.paymentWaiting,
    required this.paid,
    required this.preparing,
    required this.consultationDone,
    required this.ongoingReservation,
    this.onRetry,
  });

  final bool loading;
  final bool failed;
  final int paymentWaiting;
  final int paid;
  final int preparing;
  final int consultationDone;
  final int ongoingReservation;
  final VoidCallback? onRetry;

  List<({String label, int count})> get _items => [
        (label: '결제 대기', count: paymentWaiting),
        (label: '결제 완료', count: paid),
        (label: '배송 준비', count: preparing),
        (label: '상담 내역', count: consultationDone),
        (label: '진행 중 예약', count: ongoingReservation),
      ];

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (sum, item) => sum + item.count);
    final active = _items.where((item) => item.count > 0).toList();
    final rest = _items.where((item) => item.count == 0).toList();
    final totalText = loading ? '…' : '$total건';

    return GestureDetector(
      onTap: onRetry,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 14),
          healthDp(context, 14),
          healthDp(context, 14),
          healthDp(context, 14),
        ),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0xFFECECEF),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x0E1B1719),
              blurRadius: healthDp(context, 36),
              offset: Offset(0, healthDp(context, 10)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        failed ? '진행 중인 내역을 불러오지 못했습니다' : '진행 중인 내역',
                        style: TextStyle(
                          color: const Color(0xFF77777D),
                          fontSize: healthSp(context, 11),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          letterSpacing: healthSp(context, -0.13),
                        ),
                      ),
                      if (!failed)
                        Padding(
                          padding: EdgeInsets.only(top: healthDp(context, 2)),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '총 ',
                                  style: TextStyle(
                                    color: const Color(0xFF19191B),
                                    fontSize: healthSp(context, 18),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    letterSpacing: healthSp(context, -0.70),
                                  ),
                                ),
                                TextSpan(
                                  text: totalText,
                                  style: TextStyle(
                                    color: const Color(0xFFFF4F87),
                                    fontSize: healthSp(context, 18),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    letterSpacing: healthSp(context, -0.70),
                                  ),
                                ),
                                TextSpan(
                                  text: '이 남아 있어요',
                                  style: TextStyle(
                                    color: const Color(0xFF19191B),
                                    fontSize: healthSp(context, 18),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    letterSpacing: healthSp(context, -0.70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!failed) ...[
                  SizedBox(width: healthDp(context, 12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 8),
                      vertical: healthDp(context, 4),
                    ),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFFF0F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      totalText,
                      style: TextStyle(
                        color: const Color(0xFFF23F78),
                        fontSize: healthSp(context, 11),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (failed)
              Padding(
                padding: EdgeInsets.only(top: healthDp(context, 8)),
                child: Text(
                  '다시 시도',
                  style: TextStyle(
                    color: const Color(0xFFF23F78),
                    fontSize: healthSp(context, 11),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else ...[
              if (!loading && active.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: healthDp(context, 12)),
                  child: Column(
                    children: [
                      for (var i = 0; i < active.length; i++) ...[
                        if (i > 0) SizedBox(height: healthDp(context, 6)),
                        _ActiveCountRow(
                          label: active[i].label,
                          countText: '${active[i].count}건',
                        ),
                      ],
                    ],
                  ),
                ),
              if (rest.isNotEmpty || loading)
                Padding(
                  padding: EdgeInsets.only(top: healthDp(context, 12)),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: healthDp(context, 10)),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(width: 1, color: Color(0xFFF0F0F2)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '그 외 내역',
                          style: TextStyle(
                            color: const Color(0xFF929297),
                            fontSize: healthSp(context, 11),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 6)),
                        Wrap(
                          spacing: healthDp(context, 12),
                          runSpacing: healthDp(context, 6),
                          children: [
                            for (final item in (loading ? _items : rest))
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${item.label} ',
                                      style: TextStyle(
                                        color: const Color(0xFF85858B),
                                        fontSize: healthSp(context, 11),
                                        fontWeight: FontWeight.w300,
                                        height: 1.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text: loading ? '…' : '${item.count}',
                                      style: TextStyle(
                                        color: const Color(0xFFB2B2B7),
                                        fontSize: healthSp(context, 11),
                                        fontWeight: FontWeight.w300,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveCountRow extends StatelessWidget {
  const _ActiveCountRow({
    required this.label,
    required this.countText,
  });

  final String label;
  final String countText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 40),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 12)),
      decoration: ShapeDecoration(
        color: const Color(0xFFFFF5F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 13)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: healthDp(context, 7),
            height: healthDp(context, 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4F87),
              borderRadius: BorderRadius.circular(healthDp(context, 3.5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1EFF4F87),
                  spreadRadius: healthDp(context, 4),
                ),
              ],
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF19191B),
                fontSize: healthSp(context, 13),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          Text(
            countText,
            style: TextStyle(
              color: const Color(0xFFF23F78),
              fontSize: healthSp(context, 15),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
