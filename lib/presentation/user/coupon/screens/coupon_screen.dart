import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/coupon/coupon_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponTabLists {
  const _CouponTabLists({
    this.available = const [],
    this.used = const [],
    this.expired = const [],
  });

  final List<Coupon> available;
  final List<Coupon> used;
  final List<Coupon> expired;

  List<Coupon> forTab(int tab) => switch (tab) {
        0 => available,
        1 => used,
        2 => expired,
        _ => const [],
      };
}

class _CouponScreenState extends State<CouponScreen> {
  UserModel? _currentUser;
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<bool> _loadFailed = ValueNotifier(false);
  final ValueNotifier<bool> _reloading = ValueNotifier(false);
  final ValueNotifier<int> _selectedCouponTab = ValueNotifier(0);
  final ValueNotifier<_CouponTabLists> _couponLists =
      ValueNotifier(const _CouponTabLists());

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _registerDisabled = Color(0xFFD2D2D2);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898383);
  static const Color _textSub = Color(0xFF898686);
  static const Color _usedRed = Color(0xFFEF4444);

  static const List<String> _emptyMessages = [
    '사용할 수 있는 쿠폰이 없습니다.',
    '사용한 쿠폰이 없습니다.',
    '만료된 쿠폰이 없습니다.',
  ];

  double _pagePadH(BuildContext context) => healthDp(context, 20);

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
    _isLoading.dispose();
    _loadFailed.dispose();
    _reloading.dispose();
    _selectedCouponTab.dispose();
    _couponLists.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading.value = true;
    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      if (user != null) {
        _currentUser = user;
        await _loadCoupons();
      }
    } catch (e) {
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _loadCoupons() async {
    if (_currentUser == null) return;
    _reloading.value = true;

    try {
      final tabs = await CouponService.loadCouponTabs(_currentUser!.id);
      if (!mounted) return;
      if (tabs == null) {
        _couponLists.value = const _CouponTabLists();
        _loadFailed.value = true;
        return;
      }
      _loadFailed.value = false;
      _couponLists.value = _CouponTabLists(
        available: _issuedOldestFirst(tabs['available'] ?? const <Coupon>[]),
        used: _recentFirst(tabs['used'] ?? const <Coupon>[], (coupon) => coupon.datetime),
        expired: _recentFirst(tabs['expired'] ?? const <Coupon>[], (coupon) => coupon.endDate),
      );
    } catch (e) {
      if (!mounted) return;
      _couponLists.value = const _CouponTabLists();
      _loadFailed.value = true;
    } finally {
      if (mounted) _reloading.value = false;
    }
  }

  String _emptyMessage(int tab) =>
      tab < _emptyMessages.length ? _emptyMessages[tab] : '';

  /// 발행이 오래된 쿠폰이 위, 최근 발행이 아래. cp_no 가 발행 순서다.
  List<Coupon> _issuedOldestFirst(List<Coupon> source) {
    final list = List<Coupon>.from(source);
    list.sort((a, b) => a.no.compareTo(b.no));
    return list;
  }

  /// 기준 시각이 최근인 쿠폰이 위.
  List<Coupon> _recentFirst(
    List<Coupon> source,
    DateTime? Function(Coupon coupon) when,
  ) {
    final list = List<Coupon>.from(source);
    list.sort((a, b) {
      final aTime = when(a);
      final bTime = when(b);
      if (aTime == null && bTime == null) return b.no.compareTo(a.no);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final byTime = bTime.compareTo(aTime);
      if (byTime != 0) return byTime;
      return b.no.compareTo(a.no);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'Gmarket Sans TTF',
        color: _textMain,
      ),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '쿠폰',
          leadingIconSize: healthDp(context, 24),
        ),
        child: ColoredBox(
          color: Colors.white,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, loading, _) {
              if (!loading && _currentUser == null) {
                return CenteredEmptyState(
                  iconWidget: CenteredEmptyState.assetIcon(
                    context,
                    AppAssets.emptyCouponIcon,
                  ),
                  message: '로그인 후 이용 가능합니다.',
                  trailing: CenteredEmptyState.loginButtonTrailing(
                    context,
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/login');
                      if (!mounted) return;
                      await _loadData();
                    },
                  ),
                );
              }
              return Stack(
            children: [
              Positioned.fill(child: _buildPageCenteredEmpty()),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _pagePadH(context),
                  healthDp(context, 10),
                  _pagePadH(context),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCouponFilterTabs(),
                    SizedBox(height: healthDp(context, 10)),
                    Expanded(child: _buildCouponBody()),
                  ],
                ),
              ),
            ],
          );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageCenteredEmpty() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, loading, _) {
        if (loading) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: _loadFailed,
          builder: (context, failed, _) {
            if (failed) return const SizedBox.shrink();
            return ValueListenableBuilder<int>(
          valueListenable: _selectedCouponTab,
          builder: (context, tab, _) {
            return ValueListenableBuilder<_CouponTabLists>(
              valueListenable: _couponLists,
              builder: (context, lists, _) {
                if (lists.forTab(tab).isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: CenteredEmptyState(
                    fillAvailable: false,
                    iconWidget: CenteredEmptyState.assetIcon(
                      context,
                      AppAssets.emptyCouponIcon,
                    ),
                    message: _currentUser == null
                        ? '로그인 후 이용 가능합니다.'
                        : _emptyMessage(tab),
                  ),
                );
              },
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _buildCouponBody() {
    return ValueListenableBuilder<bool>(
      valueListenable: _loadFailed,
      builder: (context, failed, _) {
        if (!failed) return _buildCouponList();
        return ValueListenableBuilder<bool>(
          valueListenable: _reloading,
          builder: (context, reloading, _) {
            if (reloading) {
              return const Center(
                child: CircularProgressIndicator(color: _pink),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: healthDp(context, 28)),
                Text(
                  '쿠폰을 불러오지 못했습니다.',
                  textAlign: TextAlign.center,
                  style: _couponText(
                    context,
                    size: 14,
                    color: _textSub,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: healthDp(context, 16)),
                SizedBox(
                  height: healthDp(context, 44),
                  child: ElevatedButton(
                    onPressed: _loadCoupons,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '다시 불러오기',
                      style: _couponText(
                        context,
                        size: 14,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCouponList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, loading, _) {
        if (loading) {
          return const Center(
            child: CircularProgressIndicator(color: _pink),
          );
        }
        return ValueListenableBuilder<int>(
          valueListenable: _selectedCouponTab,
          builder: (context, tab, _) {
            return ValueListenableBuilder<_CouponTabLists>(
              valueListenable: _couponLists,
              builder: (context, lists, _) {
                final filtered = lists.forTab(tab);
                if (filtered.isEmpty) return const SizedBox.shrink();
                return ListView.separated(
                  padding: EdgeInsets.only(bottom: healthDp(context, 24)),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: healthDp(context, 10)),
                  itemBuilder: (context, index) =>
                      _buildCouponCard(filtered[index], tab),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCouponFilterTabs() {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedCouponTab,
      builder: (context, selected, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _loadFailed,
          builder: (context, failed, _) {
            return ValueListenableBuilder<_CouponTabLists>(
          valueListenable: _couponLists,
          builder: (context, lists, _) {
            final availableCount = failed ? null : lists.available.length;
            return SizedBox(
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildTabChip(
                      0,
                      '사용가능한 쿠폰',
                      availableCount,
                      selected,
                    ),
                  ),
                  Expanded(
                    child: _buildTabChip(
                      1,
                      '사용한 쿠폰',
                      lists.used.length,
                      selected,
                    ),
                  ),
                  Expanded(
                    child: _buildTabChip(
                      2,
                      '지난 쿠폰',
                      lists.expired.length,
                      selected,
                    ),
                  ),
                ],
              ),
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _buildTabChip(
    int index,
    String label,
    int? count,
    int selectedTab,
  ) {
    final selected = selectedTab == index;
    final title = count == null ? label : '$label$count';

    return GestureDetector(
      onTap: () => _selectedCouponTab.value = index,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                selected && index == 0 ? title : label,
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
            SizedBox(height: healthDp(context, 4)),
            Container(
              width: double.infinity,
              height: healthDp(context, 1),
              color: selected ? _pink : const Color(0xFFD2D2D2),
            ),
          ],
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

  Widget _buildCouponCard(Coupon coupon, int tabIndex) {
    final dateLine = coupon.formattedDateRange.replaceAll('–', '~');
    final usedDateLine = _formatUsedDate(coupon.datetime);
    final appliedLine = coupon.displayAppliedLine;
    final minMaxLine = coupon.minMaxOrderDescription;
    final showUsageDetail = tabIndex == 0;
    final showOrderId = tabIndex == 1 && coupon.hasOrderId;

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
                style: _couponText(context, size: 10, color: _textSub),
              ),
              Text(
                coupon.subject.isNotEmpty ? coupon.subject : '쿠폰',
                style: _couponText(context, size: 14, color: _textMain),
              ),
              if ((showUsageDetail && appliedLine.isNotEmpty) ||
                  (showUsageDetail && minMaxLine != null) ||
                  showOrderId)
                SizedBox(height: healthDp(context, 4)),
              if (showUsageDetail && appliedLine.isNotEmpty)
                Text(
                  appliedLine,
                  style: _couponText(
                    context,
                    size: 10,
                    color: _textSub,
                    weight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              if (showUsageDetail && minMaxLine != null)
                Text(
                  minMaxLine,
                  style: _couponText(
                    context,
                    size: 10,
                    color: _textSub,
                    weight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              if (showOrderId)
                Text(
                  '주문번호: ${coupon.orderId}',
                  style: _couponText(
                    context,
                    size: 10,
                    color: _textMain,
                    weight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
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
