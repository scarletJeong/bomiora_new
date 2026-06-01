import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/models/user/user_model.dart';
import 'profile_settings_screen.dart';
import '../../../customer_service/screens/contact_list_screen.dart';
import 'address_list_screen.dart';
import '../../../shopping/wish/screens/wish_list_screen.dart';
import 'refund_account_screen.dart';
import 'cancel_member_screen.dart';
import '../../healthprofile/screens/health_profile_list_screen.dart';
import '../widgets/my_page_common.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../settings/settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  UserModel? _currentUser;
  bool _statsLoading = false;
  int _orderCount = 0;
  int _couponCount = 0;
  int _pointBalance = 0;

  static int _orderCountFromResult(Map<String, dynamic> result) {
    if (result['success'] != true) return 0;
    final total = result['totalItems'];
    if (total is int && total > 0) return total;
    if (total is num && total > 0) return total.toInt();
    final orders = result['orders'];
    if (orders is List) return orders.length;
    return 0;
  }

  Future<void> _loadMyPageStats() async {
    final u = _currentUser;
    if (u == null) {
      if (mounted) {
        setState(() => _statsLoading = false);
      }
      return;
    }

    try {
      final results = await Future.wait([
        OrderService.getOrderList(
          mbId: u.id,
          period: 0,
          status: 'all',
          page: 0,
          size: 1,
        ),
        CouponService.getAvailableCoupons(u.id),
        PointService.getUserPoint(u.id),
      ]);

      if (!mounted) return;

      final orderResult = results[0] as Map<String, dynamic>;
      final coupons = results[1] as List<dynamic>;
      final point = results[2] as int?;

      setState(() {
        _orderCount = _orderCountFromResult(orderResult);
        _couponCount = coupons.length;
        _pointBalance = point ?? 0;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orderCount = 0;
        _couponCount = 0;
        _pointBalance = 0;
        _statsLoading = false;
      });
    }
  }

  Future<void> _showPasswordConfirmDialog() async {
    if (_currentUser == null) return;

    final controller = TextEditingController();
    bool mismatch = false;
    bool submitting = false;

    Future<void> submit(StateSetter setLocalState) async {
      final pw = controller.text;
      if (pw.isEmpty) {
        setLocalState(() => mismatch = true);
        return;
      }

      setLocalState(() {
        submitting = true;
        mismatch = false;
      });

      final ok = await AuthService.verifyPassword(
        mbId: _currentUser!.id,
        password: pw,
      );

      if (!mounted) return;

      if (!ok) {
        setLocalState(() {
          submitting = false;
          mismatch = true;
        });
        return;
      }

      Navigator.of(context).pop(); // close dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileSettingsScreen(),
        ),
      ).then((_) => _loadCurrentUser());
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final baseTheme = Theme.of(dialogContext);
        final gmarketTheme = baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme:
              baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
        );
        return Theme(
          data: gmarketTheme,
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              final dialogRadius = healthDp(ctx, 20);
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: healthDp(ctx, 272),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(dialogRadius)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x19000000),
                        blurRadius: healthDp(ctx, 8.14),
                        offset: Offset.zero,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          healthDp(ctx, 20),
                          healthDp(ctx, 20),
                          healthDp(ctx, 20),
                          0,
                        ),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                              fontFamily: 'Gmarket Sans TTF'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '비밀번호 확인',
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1A),
                                  fontSize: healthSp(ctx, 20),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              SizedBox(height: healthDp(ctx, 20)),
                              Text(
                                '***',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFD2D2D2),
                                  fontSize: healthSp(ctx, 14),
                                  fontWeight: FontWeight.w500,
                                  height: 1.57,
                                  letterSpacing: healthDp(ctx, 4.90),
                                ),
                              ),
                              SizedBox(height: healthDp(ctx, 20)),
                              Text(
                                '안전한 정보 변경을 위해,\n비밀번호를 한 번 더 입력해 주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF898686),
                                  fontSize: healthSp(ctx, 14),
                                  fontWeight: FontWeight.w500,
                                  height: 1.57,
                                ),
                              ),
                              SizedBox(height: healthDp(ctx, 20)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: healthDp(ctx, 40),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: healthDp(ctx, 10),
                                    ),
                                    decoration: ShapeDecoration(
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          width: healthDp(ctx, 1),
                                          color: mismatch
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFD2D2D2),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                            healthDp(ctx, 10)),
                                      ),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: TextField(
                                      controller: controller,
                                      obscureText: true,
                                      autofocus: true,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: submitting
                                          ? null
                                          : (_) => submit(setLocalState),
                                      onChanged: (_) {
                                        if (mismatch) {
                                          setLocalState(
                                              () => mismatch = false);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isCollapsed: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '비밀번호를 입력해 주세요',
                                        hintStyle: TextStyle(
                                          color: const Color(0xFF898686),
                                          fontSize: healthSp(ctx, 12),
                                          fontWeight: FontWeight.w500,
                                          height: 1,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: const Color(0xFF1A1A1A),
                                        fontSize: healthSp(ctx, 12),
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  if (mismatch) ...[
                                    SizedBox(height: healthDp(ctx, 4)),
                                    Text(
                                      '비밀번호가 일치하지 않습니다.',
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: healthSp(ctx, 10),
                                        fontWeight: FontWeight.w300,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 20)),
                      SizedBox(
                        height: healthDp(ctx, 50),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Material(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(dialogRadius),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: submitting
                                      ? null
                                      : () => Navigator.of(ctx).pop(),
                                  child: Center(
                                    child: Text(
                                      '취소',
                                      style: TextStyle(
                                        color: const Color(0xFF898686),
                                        fontSize: healthSp(ctx, 16),
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Gmarket Sans TTF',
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Material(
                                color: const Color(0xFFFF5A8D),
                                borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(dialogRadius),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: submitting
                                      ? null
                                      : () => submit(setLocalState),
                                  child: Center(
                                    child: Text(
                                      submitting ? '확인 중...' : '확인',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(ctx, 16),
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Gmarket Sans TTF',
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _currentUser = null;
        _statsLoading = false;
      });
      return;
    }

    setState(() {
      _currentUser = user;
      _statsLoading = true;
    });
    await _loadMyPageStats();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );

    return Theme(
      data: gmarketTheme,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: ColoredBox(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                      padding: EdgeInsets.fromLTRB(
                        healthDp(context, 27),
                        healthDp(context, 24),
                        healthDp(context, 27),
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageTitleBar(),
                          SizedBox(height: healthDp(context, 20)),
                          if (_currentUser == null)
                            _buildGuestHeader()
                          else
                            _buildProfileHeader(),
                          SizedBox(height: healthDp(context, 30)),
                          _buildStatsRow(),
                          SizedBox(height: healthDp(context, 20)),
                          MyPageLineMenuItem(
                            title: '찜 목록',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const WishListScreen()),
                              );
                            },
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          MyPageLineMenuItem(
                            title: '배송지 관리',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AddressManagementScreen()),
                              );
                            },
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          MyPageLineMenuItem(
                            title: '환불 계좌 등록',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const RefundAccountScreen()),
                              );
                            },
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          MyPageLineMenuItem(
                            title: '내 리뷰 활동',
                            onTap: () =>
                                Navigator.pushNamed(context, '/my_reviews'),
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          MyPageLineMenuItem(
                            title: '1:1 문의',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ContactListScreen()),
                              );
                            },
                          ),
                          SizedBox(height: healthDp(context, 20)),
                          MyPageLineMenuItem(
                            title: '문진표 관리',
                            isLast: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const HealthProfileListScreen()),
                            ),
                          ),
                          if (_currentUser != null) ...[
                            SizedBox(height: healthDp(context, 20)),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const CancelMemberScreen()),
                                ),
                                borderRadius: BorderRadius.circular(
                                    healthDp(context, 8)),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: healthDp(context, 6),
                                    vertical: healthDp(context, 6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '회원탈퇴',
                                        style: TextStyle(
                                          color: const Color(0xFF898686),
                                          fontSize: healthSp(context, 12),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: healthDp(context, 2)),
                                      Icon(
                                        Icons.chevron_right,
                                        size: healthDp(context, 18),
                                        color: const Color(0xFF898686),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: healthDp(context, 24)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildPageTitleBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left,
                color: const Color(0xFF1A1A1E),
                size: healthDp(context, 24),
              ),
              Text(
                '마이페이지',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
          child: SvgPicture.asset(
            AppAssets.mypageSettingsIcon,
            width: healthDp(context, 30),
            height: healthDp(context, 30),
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoIcon() {
    return SvgPicture.asset(
      AppAssets.mypagePhotoProfileIcon,
      width: healthDp(context, 77),
      height: healthDp(context, 77),
      fit: BoxFit.contain,
    );
  }

  Widget _buildPersonalInfoAction() {
    final textStyle = TextStyle(
      color: const Color(0xFFD2D2D2),
      fontSize: healthSp(context, 8),
      fontWeight: FontWeight.w700,
    );

    return InkWell(
      onTap: _showPasswordConfirmDialog,
      borderRadius: BorderRadius.circular(healthDp(context, 8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: healthDp(context, 1),
            height: healthDp(context, 33),
            color: const Color(0xFFD2D2D2),
          ),
          SizedBox(width: healthDp(context, 10)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.mypagePersonalInfoSettingsIcon,
                width: healthDp(context, 24),
                height: healthDp(context, 24),
                fit: BoxFit.contain,
              ),
              Text(
                '개인정보수정',
                style: textStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              MyPageAvatarFrame(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 45)),
                  child: _buildProfilePhotoIcon(),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_currentUser?.name ?? ''} 님',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 16),
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text(
                      _currentUser?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 12),
                        fontWeight: FontWeight.w300,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        _buildPersonalInfoAction(),
      ],
    );
  }

  Widget _buildGuestHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              MyPageAvatarFrame(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 45)),
                  child: _buildProfilePhotoIcon(),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '로그인이 필요해요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 16),
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    Text(
                      '로그인 후 마이페이지 기능을 이용해보세요',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 9),
                        fontWeight: FontWeight.w300,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3787),
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 14),
              vertical: healthDp(context, 10),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
            elevation: 0,
          ),
          child: Text(
            '로그인',
            style: TextStyle(
              fontSize: healthSp(context, 13),
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final orderVal = _statsLoading ? '…' : '$_orderCount';
    final couponVal = _statsLoading ? '…' : '$_couponCount';
    final pointVal =
        _statsLoading ? '…' : PointService.formatPoint(_pointBalance);

    Widget statCard({
      required String icon,
      required double iconWidth375,
      required double iconHeight375,
      required String value,
      required String unit,
      required String label,
      required VoidCallback onTap,
    }) {
      final iconW = healthDp(context, iconWidth375);
      final iconH = healthDp(context, iconHeight375);

      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
          child: AspectRatio(
            aspectRatio: 1.1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight = constraints.maxHeight;
                final iconTop = (cardHeight * -0.10).clamp(-12.0, -6.0);
                final contentTop = (iconTop + iconH + healthDp(context, 4))
                    .clamp(12.0, 28.0);
                final contentBottom = (cardHeight * 0.10).clamp(6.0, 14.0);
                return Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    SvgPicture.asset(
                      AppAssets.mypageMenuBorder,
                      fit: BoxFit.fill,
                    ),
                    Positioned(
                      top: iconTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SvgPicture.asset(
                          icon,
                          width: iconW,
                          height: iconH,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        healthDp(context, 10),
                        contentTop,
                        healthDp(context, 10),
                        contentBottom,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  value,
                                  style: TextStyle(
                                    color: const Color(0xFFFF5A8D),
                                    fontSize: healthSp(context, 16),
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(width: healthDp(context, 2)),
                                Text(
                                  unit,
                                  style: TextStyle(
                                    color: const Color(0xFF898686),
                                    fontSize: healthSp(context, 12),
                                    fontWeight: FontWeight.w300,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: healthDp(context, 4)),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: healthSp(context, 10),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        statCard(
          icon: AppAssets.deliveryMain,
          iconWidth375: 35.85,
          iconHeight375: 23.33,
          value: orderVal,
          unit: '건',
          label: '주문/배송내역',
          onTap: () => Navigator.pushNamed(context, '/order'),
        ),
        SizedBox(width: healthDp(context, 14)),
        statCard(
          icon: AppAssets.couponMain,
          iconWidth375: 34.59,
          iconHeight375: 21.84,
          value: couponVal,
          unit: '장',
          label: '내쿠폰',
          onTap: () => Navigator.pushNamed(context, '/coupon'),
        ),
        SizedBox(width: healthDp(context, 14)),
        statCard(
          icon: AppAssets.pointMain,
          iconWidth375: 22.5,
          iconHeight375: 22.5,
          value: pointVal,
          unit: 'P',
          label: '포인트',
          onTap: () => Navigator.pushNamed(context, '/point'),
        ),
      ],
    );
  }
}
