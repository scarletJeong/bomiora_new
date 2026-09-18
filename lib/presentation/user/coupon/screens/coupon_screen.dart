import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/coupon/coupon_model.dart';
import '../../../common/widgets/app_toast_overlay.dart';
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
  final ValueNotifier<int> _selectedCouponTab = ValueNotifier(0);
  final ValueNotifier<_CouponTabLists> _couponLists =
      ValueNotifier(const _CouponTabLists());
  final TextEditingController _couponCodeController = TextEditingController();

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
    _selectedCouponTab.dispose();
    _couponLists.dispose();
    _couponCodeController.dispose();
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

    try {
      final tabs = await CouponService.getCouponTabs(
        _currentUser!.id,
        forceRefresh: true,
      );
      if (!mounted) return;
      _couponLists.value = _CouponTabLists(
        available: tabs['available'] ?? const <Coupon>[],
        used: tabs['used'] ?? const <Coupon>[],
        expired: tabs['expired'] ?? const <Coupon>[],
      );
    } catch (e) {
      debugPrint('쿠폰 조회 오류: $e');
    }
  }

  String _emptyMessage(int tab) =>
      tab < _emptyMessages.length ? _emptyMessages[tab] : '';

  /// `true` 성공, `false` 실패, `null` 로그인 필요 등으로 등록을 시도하지 않음
  Future<bool?> _registerCoupon() async {
    final code = _couponCodeController.text.replaceAll('-', '').trim();
    if (code.length != 16) return null;

    if (_currentUser == null) {
      await showLoginRequiredDialog(
        context,
        message: '쿠폰 등록은 로그인 후 이용할 수 있습니다.',
      );
      return null;
    }

    try {
      final result = await CouponService.registerCoupon(
        _currentUser!.id,
        _couponCodeController.text.trim(),
      );

      if (!mounted) return false;

      if (result['success'] == true) {
        _couponCodeController.clear();
        await _loadCoupons();
        if (mounted) {
          AppToastOverlay.show(context, '쿠폰이 성공적으로 등록되었습니다.');
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('쿠폰 등록 오류: $e');
      return false;
    }
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
          child: Stack(
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
                    ValueListenableBuilder<int>(
                      valueListenable: _selectedCouponTab,
                      builder: (context, tab, _) {
                        if (tab != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: healthDp(context, 10),
                          ),
                          child: _CouponRegistrationCard(
                            controller: _couponCodeController,
                            onRegister: _registerCoupon,
                          ),
                        );
                      },
                    ),
                    Expanded(child: _buildCouponList()),
                  ],
                ),
              ),
            ],
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
        return ValueListenableBuilder<_CouponTabLists>(
          valueListenable: _couponLists,
          builder: (context, lists, _) {
            return SizedBox(
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildTabChip(
                      0,
                      '사용가능한 쿠폰',
                      lists.available.length,
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
  }

  Widget _buildTabChip(
    int index,
    String label,
    int count,
    int selectedTab,
  ) {
    final selected = selectedTab == index;

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
                selected && index == 0 ? '$label$count' : label,
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

class _CouponRegistrationCard extends StatefulWidget {
  const _CouponRegistrationCard({
    required this.controller,
    required this.onRegister,
  });

  final TextEditingController controller;
  final Future<bool?> Function() onRegister;

  @override
  State<_CouponRegistrationCard> createState() =>
      _CouponRegistrationCardState();
}

class _CouponRegistrationCardState extends State<_CouponRegistrationCard> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _registerDisabled = Color(0xFFD2D2D2);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _usedRed = Color(0xFFEF4444);

  final ValueNotifier<bool> _registerError = ValueNotifier(false);
  final ValueNotifier<bool> _registering = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCodeChanged);
  }

  @override
  void didUpdateWidget(covariant _CouponRegistrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCodeChanged);
      widget.controller.addListener(_onCodeChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCodeChanged);
    _registerError.dispose();
    _registering.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_registerError.value) _registerError.value = false;
  }

  Future<void> _onRegisterTap() async {
    if (_registering.value) return;
    final enabled =
        widget.controller.text.replaceAll('-', '').trim().length == 16;
    if (!enabled) return;

    _registerError.value = false;
    _registering.value = true;
    try {
      final result = await widget.onRegister();
      if (!mounted) return;
      if (result == false) _registerError.value = true;
    } finally {
      if (mounted) _registering.value = false;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final underlineBorder = UnderlineInputBorder(
      borderSide: BorderSide(width: healthDp(context, 1), color: _border),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 15)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '쿠폰등록하기',
            style: _couponText(context, size: 14, color: _textMain, height: 1),
          ),
          SizedBox(height: healthDp(context, 10)),
          Container(
            height: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
          SizedBox(height: healthDp(context, 10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      maxLength: 19,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: const [_CouponCodeFormatter()],
                      autocorrect: false,
                      enableSuggestions: false,
                      mouseCursor: SystemMouseCursors.text,
                      style: _couponText(context, size: 12, color: _textMain),
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: '쿠폰 코드를 입력해주세요',
                        hintStyle: _couponText(
                          context,
                          size: 12,
                          color: const Color(0xFFD2D2D2),
                          weight: FontWeight.w300,
                        ),
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
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _registering,
                        builder: (context, registering, _) {
                          final enabled = value.text
                                  .replaceAll('-', '')
                                  .trim()
                                  .length ==
                              16 &&
                              !registering;
                          return GestureDetector(
                            onTap: enabled ? _onRegisterTap : null,
                            child: SizedBox(
                              height: healthDp(context, 34),
                              child: Container(
                                padding: EdgeInsets.all(healthDp(context, 10)),
                                alignment: Alignment.center,
                                decoration: ShapeDecoration(
                                  color: enabled ? _pink : _registerDisabled,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      healthDp(context, 7),
                                    ),
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
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _registerError,
                builder: (context, showError, _) {
                  if (!showError) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(top: healthDp(context, 4)),
                    child: Text(
                      '쿠폰정보를 다시 입력해주세요.',
                      style: _couponText(
                        context,
                        size: 10,
                        color: _usedRed,
                        weight: FontWeight.w300,
                        height: 1,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponCodeFormatter extends TextInputFormatter {
  const _CouponCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final clipped = raw.length > 16 ? raw.substring(0, 16) : raw;
    final buf = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(clipped[i]);
    }
    final text = buf.toString();
    if (text == oldValue.text &&
        oldValue.selection.baseOffset == text.length) {
      return oldValue;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
