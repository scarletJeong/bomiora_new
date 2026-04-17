import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/delivery_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../settings/settings_screen.dart';
import '../../../settings/notification_center_screen.dart';
import '../../../common/widgets/appbar_menutap.dart';
import 'profile_settings_screen.dart';
import '../../../customer_service/screens/contact_list_screen.dart';
import 'address_management_screen.dart';
import '../../../shopping/wish/screens/wish_list_screen.dart';
import 'refund_account_screen.dart';
import 'cancel_member_screen.dart';
import '../../healthprofile/screens/health_profile_list_screen.dart';
import '../widgets/my_page_common.dart';

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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 272,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 8.14,
                      offset: Offset(0, 0),
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
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '비밀번호 확인',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '***',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD2D2D2),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.57,
                                letterSpacing: 4.90,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '안전한 정보 변경을 위해,\n비밀번호를 한 번 더 입력해 주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF898686),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.57,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        width: 1,
                                        color: mismatch
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFD2D2D2),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: controller,
                                    obscureText: true,
                                    onChanged: (_) {
                                      if (mismatch)
                                        setLocalState(() => mismatch = false);
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: '비밀번호를 입력해 주세요',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF898686),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (mismatch) ...[
                                  const SizedBox(height: 5),
                                  const Text(
                                    '비밀번호가 일치하지 않습니다.',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 50,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF7F7F7),
                              child: InkWell(
                                onTap: submitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Center(
                                  child: Text(
                                    '취소',
                                    style: TextStyle(
                                      color: Color(0xFF898686),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Gmarket Sans TTF',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Material(
                              color: const Color(0xFFFF5A8D),
                              child: InkWell(
                                onTap: submitting
                                    ? null
                                    : () => submit(setLocalState),
                                child: Center(
                                  child: Text(
                                    submitting ? '확인 중...' : '확인',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Gmarket Sans TTF',
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
    return MobileAppLayoutWrapper(
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/health');
        },
      ),
      appBar: AppBar(
        title: Image.asset(
          AppAssets.bomioraLogo,
          height: 40,
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '알림 설정',
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationCenterScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: ColoredBox(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                if (_currentUser == null)
                  _buildGuestHeader()
                else
                  _buildProfileHeader(),
                const SizedBox(height: 40),
                _buildStatsRow(),
                const SizedBox(height: 30),
                MyPageLineMenuItem(
                  title: '찜 목록',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const WishListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                MyPageLineMenuItem(
                  title: '환불 계좌 등록',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RefundAccountScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                MyPageLineMenuItem(
                  title: '내 리뷰 활동',
                  onTap: () => Navigator.pushNamed(context, '/my_reviews'),
                ),
                const SizedBox(height: 10),
                MyPageLineMenuItem(
                  title: '1:1 문의',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ContactListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                MyPageLineMenuItem(
                  title: '건강프로필 관리',
                  isLast: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HealthProfileListScreen()),
                  ),
                ),
                if (_currentUser != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CancelMemberScreen()),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '회원탈퇴',
                              style: TextStyle(
                                color: Color(0xFF898686),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFF898686),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Footer 숨김
                // const AppFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            MyPageAvatarFrame(
              child: const Icon(
                Icons.person,
                size: 44,
                color: Color(0xFFD2D2D2),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentUser?.name ?? ''} 님',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _currentUser?.email ?? '',
                  style: const TextStyle(
                    color: Color(0xFF898686),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: _showPasswordConfirmDialog,
          borderRadius: BorderRadius.circular(8),
          child: const Column(
            children: [
              Icon(Icons.settings_outlined, color: Color(0xFFD2D2D2), size: 30),
              Text(
                '개인정보수정',
                style: TextStyle(
                  color: Color(0xFFD2D2D2),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            MyPageAvatarFrame(
              child: const Icon(
                Icons.person_outline,
                size: 44,
                color: Color(0xFFD2D2D2),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '로그인이 필요해요',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '로그인 후 마이페이지 기능을 이용해보세요',
                  style: TextStyle(
                    color: Color(0xFF898686),
                    fontSize: 9,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3787),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            '로그인',
            style: TextStyle(
              fontSize: 13,
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
      required String value,
      required String unit,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1.1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 카드 너비에 맞춰 아이콘/높이를 함께 유동 스케일
                final iconSize =
                    (constraints.maxWidth * 0.27).clamp(20.0, 34.0);
                final cardHeight = constraints.maxHeight;
                final iconTop = (cardHeight * -0.10).clamp(-12.0, -6.0);
                final contentTop = (iconSize * 0.95).clamp(18.0, 30.0);
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
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          10, contentTop, 10, contentBottom),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                value,
                                style: const TextStyle(
                                  color: Color(0xFFFF5A8D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                unit,
                                style: const TextStyle(
                                  color: Color(0xFF898686),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
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
          value: orderVal,
          unit: '건',
          label: '주문/배송내역',
          onTap: () => Navigator.pushNamed(context, '/order'),
        ),
        const SizedBox(width: 20),
        statCard(
          icon: AppAssets.couponMain,
          value: couponVal,
          unit: '장',
          label: '내쿠폰',
          onTap: () => Navigator.pushNamed(context, '/coupon'),
        ),
        const SizedBox(width: 20),
        statCard(
          icon: AppAssets.pointMain,
          value: pointVal,
          unit: 'P',
          label: '포인트',
          onTap: () => Navigator.pushNamed(context, '/point'),
        ),
      ],
    );
  }
}
