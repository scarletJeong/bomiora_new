import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/services/notification_inbox_service.dart';
import '../../../data/services/prescription_purchase_history_service.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../settings/notification_center_screen.dart';
import '../../settings/settings_screen.dart';
import '../../shopping/screens/cart_general_screen.dart' as cart_general;
import '../../shopping/screens/cart_integration_screen.dart';
import '../../home/search/search_popup.dart';
import 'cart_dropdown_menu.dart';

/// 홈: 검색·알림·장바구니 / 마이페이지: 장바구니·설정
enum AppBarMenuActionsStyle { home, myPage }

/// [HealthAppBar]와 동일한 전체 높이(375 기준 60, 패널 폭에 맞춰 최대 90).
/// 좌우 패딩 20, 메뉴 16×12, 우측 아이콘 20, 아이콘 간격 8, 로고 94.09×20.
/// 로고는 화면 가로 정중앙. 길이는 [healthDp]로 스케일합니다.
class AppBarMenu extends StatefulWidget
    implements HealthResponsivePreferredSizeWidget {
  final VoidCallback onMenuPressed;

  /// 지정 시 검색 아이콘 탭 동작 (미지정이면 무동작)
  final VoidCallback? onSearchPressed;
  final AppBarMenuActionsStyle actionsStyle;

  const AppBarMenu({
    super.key,
    required this.onMenuPressed,
    this.onSearchPressed,
    this.actionsStyle = AppBarMenuActionsStyle.home,
  });

  @override
  Size get preferredSize => healthAppBarPreferredSize();

  @override
  Size preferredSizeForWidth(double width) =>
      healthAppBarPreferredSize(width: width);

  @override
  State<AppBarMenu> createState() => _AppBarMenuState();
}

class _AppBarMenuState extends State<AppBarMenu> {
  final GlobalKey _cartIconKey = GlobalKey();
  OverlayEntry? _cartOverlay;
  bool _cartNavigating = false;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    NotificationInboxService.revision.addListener(_loadUnreadNotificationCount);
    _loadUnreadNotificationCount();
  }

  @override
  void dispose() {
    NotificationInboxService.revision
        .removeListener(_loadUnreadNotificationCount);
    _removeCartOverlay();
    super.dispose();
  }

  Future<void> _loadUnreadNotificationCount() async {
    final items = await NotificationInboxService.fetchList(
      unreadOnly: true,
      allowServer: false,
    );
    if (!mounted) return;
    setState(() {
      _unreadNotificationCount = items.length;
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cartOverlay?.remove();
      _cartOverlay = null;
    });
  }

  void _removeCartOverlay() {
    _cartOverlay?.remove();
    _cartOverlay = null;
  }

  void _toggleCartMenu() {
    if (_cartOverlay != null) {
      _removeCartOverlay();
      return;
    }
    _onCartIconPressed();
  }

  Future<void> _onCartIconPressed() async {
    if (_cartNavigating) return;
    _cartNavigating = true;
    try {
      final useIntegrated =
          await PrescriptionPurchaseHistoryService.shouldUseIntegratedCart();
      if (!mounted) return;
      if (useIntegrated) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CartIntegrationScreen(),
          ),
        );
        return;
      }
      _openCartMenu();
    } finally {
      _cartNavigating = false;
    }
  }

  void _openCartMenu() {
    if (_cartOverlay != null) return;
    final anchorContext = _cartIconKey.currentContext;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.attached) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);

    final menuW = cartDropdownWidth(context);
    double left = anchorTopLeft.dx + anchorBox.size.width - menuW;
    double top = anchorTopLeft.dy + anchorBox.size.height + 4;
    if (overlayBox != null) {
      left = left.clamp(8, overlayBox.size.width - menuW - 8);
      final menuH = healthDp(context, 66);
      top = top.clamp(8, overlayBox.size.height - menuH - 8);
    }

    _cartOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeCartOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: CartDropdownMenuPanel(
                onPrescriptionTap: () {
                  _removeCartOverlay();
                  Navigator.pushNamed(context, '/cart');
                },
                onShoppingTap: () {
                  _removeCartOverlay();
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const cart_general.CartScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_cartOverlay!);
  }

  Widget _leadingMenu({
    required double width,
    required double height,
    required double iconW,
    required double iconH,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Align(
            alignment: Alignment.center,
            child: SvgPicture.asset(
              AppAssets.menuIcon,
              width: iconW,
              height: iconH,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionSvg({
    Key? key,
    required String asset,
    required VoidCallback onPressed,
    required double width,
    required double height,
    required double iconSz,
    Widget? badge,
  }) {
    return SizedBox(
      key: key,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                asset,
                width: iconSz,
                height: iconSz,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
              if (badge != null)
                Positioned(
                  top: (height - iconSz) / 2 - healthDp(context, 4),
                  right: (width - iconSz) / 2 - healthDp(context, 6),
                  child: badge,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _notificationCountBadge() {
    final count = _unreadNotificationCount;
    if (count <= 0) return null;
    final label = count > 99 ? '99+' : '$count';
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: healthDp(context, 16)),
      child: Container(
        height: healthDp(context, 16),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 4)),
        decoration: ShapeDecoration(
          color: const Color(0xFFFF5A8D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = healthStatusBarTopInset(context);
    final barH = healthAppBarTotalHeight(context);
    final padH = healthDp(context, 20);
    final padV = healthDp(context, 18);
    final iconSz = healthDp(context, 20);
    final menuIconW = healthDp(context, 16);
    final menuIconH = healthDp(context, 12);
    final actionGap = healthDp(context, 8);
    final logoW = healthDp(context, 94.09);
    final logoH = healthDp(context, 20);

    final isMyPage = widget.actionsStyle == AppBarMenuActionsStyle.myPage;

    Widget actionBox({
      Key? key,
      required String asset,
      required VoidCallback onPressed,
      Widget? badge,
      double? drawSize,
    }) {
      return _actionSvg(
        key: key,
        asset: asset,
        width: iconSz,
        height: iconSz,
        iconSz: drawSize ?? iconSz,
        badge: badge,
        onPressed: onPressed,
      );
    }

    final List<Widget> actionChildren = isMyPage
        ? [
            actionBox(
              key: _cartIconKey,
              asset: AppAssets.appbarCartIcon,
              onPressed: _toggleCartMenu,
            ),
            SizedBox(width: actionGap),
            actionBox(
              asset: AppAssets.appbarSettingsIcon,
              drawSize: healthDp(context, 15.08),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ]
        : [
            actionBox(
              asset: AppAssets.appbarSearchIcon,
              onPressed: () {
                if (widget.onSearchPressed != null) {
                  widget.onSearchPressed!();
                } else {
                  SearchPopup.show(context);
                }
              },
            ),
            SizedBox(width: actionGap),
            actionBox(
              asset: AppAssets.appbarAlarmIcon,
              badge: _notificationCountBadge(),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationCenterScreen(),
                  ),
                );
              },
            ),
            SizedBox(width: actionGap),
            actionBox(
              key: _cartIconKey,
              asset: AppAssets.appbarCartIcon,
              onPressed: _toggleCartMenu,
            ),
          ];

    return SizedBox(
      height: barH + topInset,
      width: double.infinity,
      child: Material(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              child: SizedBox(
                height: barH - padV * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _leadingMenu(
                          width: menuIconW,
                          height: menuIconH,
                          iconW: menuIconW,
                          iconH: menuIconH,
                          onPressed: widget.onMenuPressed,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: actionChildren,
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/home',
                            (route) => false,
                          );
                        },
                        child: SizedBox(
                          width: logoW,
                          height: logoH,
                          child: SvgPicture.asset(
                            AppAssets.bomioraAppbarLogo,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
