import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/coupon/coupon_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/login_required_dialog.dart';

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

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898383);
  static const Color _textSub = Color(0xFF898686);

  @override
  void dispose() {
    _couponCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        await _loadCoupons();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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

      setState(() {
        _availableCoupons = results[0];
        _usedCoupons = results[1];
        _expiredCoupons = results[2];
      });
    } catch (e) {
      debugPrint('쿠폰 조회 오류: $e');
    }
  }

  List<Coupon> get _filteredCoupons {
    switch (_selectedCouponTab) {
      case 0:
        return _availableCoupons;
      case 1:
        return _usedCoupons;
      case 2:
        return _expiredCoupons;
      default:
        return [];
    }
  }

  String get _emptyMessage {
    switch (_selectedCouponTab) {
      case 0:
        return '사용할 수 있는 쿠폰이 없습니다.';
      case 1:
        return '사용한 쿠폰이 없습니다.';
      case 2:
        return '만료된 쿠폰이 없습니다.';
      default:
        return '';
    }
  }

  Future<void> _registerCoupon() async {
    if (_couponCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('쿠폰 코드를 입력해주세요.')),
      );
      return;
    }

    if (_currentUser == null) {
      await showLoginRequiredDialog(
        context,
        message: '쿠폰 등록은 로그인 후 이용할 수 있습니다.',
      );
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? '등록에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('쿠폰 등록 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '쿠폰',
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF5A8D),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredCoupons;

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        clipBehavior: Clip.antiAlias,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 27),
              sliver: SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildCouponSummaryCard(),
                    const SizedBox(height: 20),
                    _buildCouponFilterTabs(),
                    const SizedBox(height: 20),
                    if (_selectedCouponTab == 0) ...[
                      _buildCouponRegistration(),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontFamily: 'Gmarket Sans TTF',
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(27, 0, 27, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(bottom: index < filtered.length - 1 ? 10 : 0),
                      child: _buildCouponCard(filtered[index], _selectedCouponTab),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponSummaryCard() {
    final count = _availableCoupons.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: _border,
          ),
          borderRadius: BorderRadius.circular(7),
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
                  SvgPicture.asset(
                    AppAssets.couponIcon,
                    width: 80,
                    height: 80,
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
                const Text(
                  '내 쿠폰',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: _pink,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
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
          width: 0.5,
          height: 11,
          color: const Color(0xFFD2D2D2),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTabChip(0, '사용가능한 쿠폰')),
        vDivider(),
        Expanded(child: _buildTabChip(1, '사용한 쿠폰')),
        vDivider(),
        Expanded(child: _buildTabChip(2, '지난 쿠폰')),
      ],
    );
  }

  Widget _buildTabChip(int index, String label) {
    final selected = _selectedCouponTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCouponTab = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _pink : _textMuted,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 1,
              color: selected ? _pink : Colors.transparent,
            ),
          ],
        ),
      ),
    );
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
            width: 272,
            padding: const EdgeInsets.all(20),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 8.14,
                  offset: Offset(0, 0),
                  spreadRadius: 0,
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
                  const Text(
                    '쿠폰 등록',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '쿠폰이 성공적으로 등록되었습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        padding: const EdgeInsets.all(10),
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          color: _pink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '확인',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
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
    const underlineBorder = UnderlineInputBorder(
      borderSide: BorderSide(width: 1, color: _border),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '쿠폰등록하기',
            style: TextStyle(
              color: _textMain,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFD2D2D2)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCodeController,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    color: _textMain,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '쿠폰 코드를 입력해주세요',
                    hintStyle: const TextStyle(
                      color: _textMuted,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.only(bottom: 8, top: 4),
                    border: underlineBorder,
                    enabledBorder: underlineBorder,
                    focusedBorder: underlineBorder,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: const Color(0xFFD2D2D2),
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: _registerCoupon,
                  borderRadius: BorderRadius.circular(7),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(
                      '등록',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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
    );
  }

  Widget _buildCouponCard(Coupon coupon, int tabIndex) {
    final dateLine = coupon.formattedDateRange.replaceAll('–', '~');
    final appliedLine = coupon.displayAppliedLine;
    final minMaxLine = coupon.minMaxOrderDescription;
    final showUsageDetail = tabIndex != 1;
    final showOrderId = tabIndex == 1 &&
        coupon.orderId != null &&
        coupon.orderId! > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLine,
            style: const TextStyle(
              color: _textMain,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: _border),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '보미오라',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                coupon.subject.isNotEmpty ? coupon.subject : '쿠폰',
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showUsageDetail && appliedLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  appliedLine,
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
              if (showUsageDetail && minMaxLine != null) ...[
                const SizedBox(height: 5),
                Text(
                  minMaxLine,
                  style: const TextStyle(
                    color: _textSub,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
              if (showOrderId) ...[
                const SizedBox(height: 8),
                Text(
                  '주문번호: ${coupon.orderId}',
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                coupon.discountPrimaryLabel,
                style: const TextStyle(
                  color: _pink,
                  fontSize: 20,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
