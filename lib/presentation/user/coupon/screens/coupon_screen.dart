import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/coupon/coupon_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  UserModel? _currentUser;
  List<Coupon> _availableCoupons = [];
  List<Coupon> _usedCoupons = [];
  List<Coupon> _expiredCoupons = [];
  bool _isLoading = true;
  int _selectedCouponTab = 0;
  final TextEditingController _couponCodeController = TextEditingController();
  bool _couponRegisterError = false;

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _registerDisabled = Color(0xFFD2D2D2);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textInk = Color(0xFF1A1A1E);
  static const Color _textMuted = Color(0xFF898383);
  static const Color _textSub = Color(0xFF898686);
  static const Color _usedRed = Color(0xFFEF4444);
  static const Color _dialogShadow = Color(0x19000000);

  static const List<String> _emptyMessages = [
    '사용할 수 있는 쿠폰이 없습니다.',
    '사용한 쿠폰이 없습니다.',
    '만료된 쿠폰이 없습니다.',
  ];

  bool get _isRegisterEnabled =>
      _couponCodeController.text.trim().length == 16;

  double _pagePadH(BuildContext context) => healthDp(context, 27);

  ShapeDecoration _outlinedCardDecoration(BuildContext context) =>
      ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      );

  TextStyle _couponText(
    BuildContext context, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) =>
      TextStyle(
        color: color,
        fontSize: healthSp(context, size),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: weight,
        height: height,
      );

  Widget _solidDivider(BuildContext context, {Color? color}) => Container(
        height: healthDp(context, 1),
        color: color ?? _registerDisabled,
      );

  @override
  void dispose() {
    _couponCodeController.removeListener(_onCouponCodeChanged);
    _couponCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _couponCodeController.addListener(_onCouponCodeChanged);
    _loadData();
  }

  void _onCouponCodeChanged() {
    setState(() {
      if (_couponRegisterError) _couponRegisterError = false;
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      if (user != null) {
        setState(() => _currentUser = user);
        await _loadCoupons();
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCoupons() async {
    if (_currentUser == null) return;

    try {
      final results = await Future.wait([
        CouponService.getAvailableCoupons(_currentUser!.id),
        CouponService.getUsedCoupons(_currentUser!.id),
        CouponService.getExpiredCoupons(_currentUser!.id),
      ]);

      if (!mounted) return;
      setState(() {
        _availableCoupons = results[0];
        _usedCoupons = results[1];
        _expiredCoupons = results[2];
      });
    } catch (e) {
      debugPrint('쿠폰 조회 오류: $e');
    }
  }

  List<Coupon> get _filteredCoupons => switch (_selectedCouponTab) {
        0 => _availableCoupons,
        1 => _usedCoupons,
        2 => _expiredCoupons,
        _ => <Coupon>[],
      };

  String get _emptyMessage =>
      _selectedCouponTab < _emptyMessages.length
          ? _emptyMessages[_selectedCouponTab]
          : '';

  Future<void> _registerCoupon() async {
    if (!_isRegisterEnabled) return;

    if (_currentUser == null) {
      await showLoginRequiredDialog(
        context,
        message: '쿠폰 등록은 로그인 후 이용할 수 있습니다.',
      );
      return;
    }

    setState(() => _couponRegisterError = false);

    try {
      final result = await CouponService.registerCoupon(
        _currentUser!.id,
        _couponCodeController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _couponCodeController.clear();
        await _loadCoupons();
        if (mounted) await _showCouponRegisteredDialog();
      } else {
        setState(() => _couponRegisterError = true);
      }
    } catch (e) {
      if (mounted) setState(() => _couponRegisterError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: _textMain,
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '쿠폰',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _pink),
                  )
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredCoupons;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.white),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: _pagePadH(context)),
            sliver: SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: healthDp(context, 20)),
                  _buildCouponSummaryCard(),
                  SizedBox(height: healthDp(context, 20)),
                  _buildCouponFilterTabs(),
                  SizedBox(height: healthDp(context, 10)),
                  if (_selectedCouponTab == 0) ...[
                    _buildCouponRegistration(),
                    SizedBox(height: healthDp(context, 10)),
                  ],
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: CenteredEmptyState(
                message: _emptyMessage,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _pagePadH(context),
                0,
                _pagePadH(context),
                healthDp(context, 24),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index < filtered.length - 1
                          ? healthDp(context, 10)
                          : 0,
                    ),
                    child: _buildCouponCard(
                      filtered[index],
                      _selectedCouponTab,
                    ),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCouponSummaryCard() {
    final count = _availableCoupons.length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: _border,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: 0.80,
            child: SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: healthDp(context, 106),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.couponIcon,
                        width: healthDp(context, 80),
                        height: healthDp(context, 80),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '쿠폰',
                  style: _couponText(context, size: 14, color: _textMain, weight: FontWeight.w500),
                ),
                SizedBox(width: healthDp(context, 2)),
                Text(
                  '$count',
                  style: _couponText(
                    context,
                    size: 14,
                    color: _pink,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponFilterTabs() {
    Widget vDivider() => Container(
          width: healthDp(context, 0.5),
          height: healthDp(context, 11),
          color: _registerDisabled,
        );

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTabChip(0, '사용가능한 쿠폰'),
          vDivider(),
          _buildTabChip(1, '사용한 쿠폰'),
          vDivider(),
          _buildTabChip(2, '지난 쿠폰'),
        ],
      ),
    );
  }

  Widget _buildTabChip(int index, String label) {
    final selected = _selectedCouponTab == index;
    final tabW = healthDp(context, 99);
    final underlineH = healthDp(context, 1);

    return GestureDetector(
      onTap: () => setState(() => _selectedCouponTab = index),
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: tabW),
        child: SizedBox(
          width: tabW,
          child: Container(
            padding: EdgeInsets.only(bottom: healthDp(context, 0)),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: underlineH,
                  color: selected ? _pink : Colors.transparent,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: _couponText(
                    context,
                    size: 14,
                    color: selected ? _pink : _textMuted,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatUsedDate(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _showCouponRegisteredDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: healthDp(ctx, 272),
            padding: EdgeInsets.all(healthDp(ctx, 20)),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(ctx, 20)),
              ),
              shadows: [
                BoxShadow(
                  color: _dialogShadow,
                  blurRadius: healthDp(ctx, 8.14),
                  offset: Offset.zero,
                ),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '쿠폰 등록',
                    style: _couponText(
                      ctx,
                      size: 20,
                      color: _textInk,
                      weight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: healthDp(ctx, 20)),
                  Text(
                    '쿠폰이 성공적으로 등록되었습니다.',
                    textAlign: TextAlign.center,
                    style: _couponText(
                      ctx,
                      size: 14,
                      color: _textSub,
                      height: 1.57,
                    ),
                  ),
                  SizedBox(height: healthDp(ctx, 20)),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(healthDp(ctx, 10)),
                      child: Container(
                        width: double.infinity,
                        height: healthDp(ctx, 40),
                        padding: EdgeInsets.all(healthDp(ctx, 10)),
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          color: _pink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(healthDp(ctx, 10)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '확인',
                              style: _couponText(
                                ctx,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCouponRegistration() {
    final underlineBorder = UnderlineInputBorder(
      borderSide: BorderSide(width: healthDp(context, 1), color: _border),
    );
    final registerBtnColor =
        _isRegisterEnabled ? _pink : _registerDisabled;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 15)),
      decoration: _outlinedCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '쿠폰등록하기',
            style: _couponText(context, size: 12, color: _textMain, height: 1),
          ),
          SizedBox(height: healthDp(context, 10)),
          _solidDivider(context, color: const Color(0x7FD2D2D2)),
          SizedBox(height: healthDp(context, 10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponCodeController,
                      maxLength: 16,
                      style: _couponText(context, size: 12, color: _textMain),
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: '쿠폰 코드를 입력해주세요',
                        hintStyle:
                            _couponText(context, size: 10, color: Color(0xFFD2D2D2)),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: healthDp(context, 10),
                        ),
                        border: underlineBorder,
                        enabledBorder: underlineBorder,
                        focusedBorder: underlineBorder,
                      ),
                    ),
                  ),
                  SizedBox(width: healthDp(context, 10)),
                  GestureDetector(
                    onTap: _isRegisterEnabled ? _registerCoupon : null,
                    child: SizedBox(
                      height: healthDp(context, 34),
                      child: Container(
                        padding: EdgeInsets.all(healthDp(context, 10)),
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          color: registerBtnColor,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 7)),
                          ),
                        ),
                        child: Text(
                          '등록',
                          textAlign: TextAlign.center,
                          style: _couponText(
                            context,
                            size: 12,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_couponRegisterError) ...[
                SizedBox(height: healthDp(context, 4)),
                Text(
                  '쿠폰정보를 다시 입력해주세요.',
                  style: _couponText(
                    context,
                    size: 10,
                    color: _usedRed,
                    weight: FontWeight.w300,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Coupon coupon, int tabIndex) {
    final dateLine = coupon.formattedDateRange.replaceAll('–', '~');
    final usedDateLine = _formatUsedDate(coupon.datetime);
    final appliedLine = coupon.displayAppliedLine;
    final minMaxLine = coupon.minMaxOrderDescription;
    final showUsageDetail = tabIndex != 1;
    final showOrderId = tabIndex == 1 &&
        coupon.orderId != null &&
        coupon.orderId! > 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 15)),
      decoration: _outlinedCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tabIndex == 1)
            Row(
              children: [
                Expanded(
                  child: Text(
                    usedDateLine,
                    style: _couponText(context, size: 12, color: _textMain),
                  ),
                ),
                Text(
                  '사용완료',
                  style: _couponText(
                    context,
                    size: 10,
                    color: _usedRed,
                    weight: FontWeight.w300,
                  ),
                ),
              ],
            )
          else
            Text(
              dateLine,
              style: _couponText(context, size: 12, color: _textMain),
            ),
          SizedBox(height: healthDp(context, 10)),
          _solidDivider(context, color: const Color(0x7FD2D2D2)),
          SizedBox(height: healthDp(context, 10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '보미오라',
                style: _couponText(context, size: 12, color: _textSub),
              ),
              Text(
                coupon.subject.isNotEmpty ? coupon.subject : '쿠폰',
                style: _couponText(context, size: 14, color: _textMain),
              ),
              if (showUsageDetail && appliedLine.isNotEmpty) ...[
                SizedBox(height: healthDp(context, 4)),
                Text(
                  appliedLine,
                  style: _couponText(
                    context,
                    size: 10,
                    color: _textSub,
                    height: 1.35,
                  ),
                ),
              ],
              if (showUsageDetail && minMaxLine != null)
                Text(
                  minMaxLine,
                  style: _couponText(
                    context,
                    size: 10,
                    color: _textSub,
                    height: 1.35,
                  ),
                ),
              if (showOrderId) ...[
                SizedBox(height: healthDp(context, 5)),
                Text(
                  '주문번호: ${coupon.orderId}',
                  style: _couponText(
                    context,
                    size: 10,
                    color: _textMain,
                    weight: FontWeight.w300,
                  ),
                ),
              ],
              SizedBox(height: healthDp(context, 10)),
              Text(
                coupon.discountPrimaryLabel,
                style: _couponText(
                  context,
                  size: 16,
                  color: _pink,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
