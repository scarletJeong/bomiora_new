import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../settings/notification_center_screen.dart';
import '../../shopping/screens/cart_general_screen.dart' as cart_general;
import '../../home/search/search_popup.dart';
import 'cart_dropdown_menu.dart';

/// 햄버거 메뉴 + [AppAssets.bomioraAppbarLogo] + 선택적 액션. 뒤로가기(leading) 없음.
///
/// 툴바 높이·elevation/surfaceTint는 [HealthAppBar]와 유사하며 배경은 불투명 흰색입니다.
class AppBarMenu extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;
  /// 지정 시 검색 아이콘 탭 동작 (미지정이면 무동작)
  final VoidCallback? onSearchPressed;

  const AppBarMenu({
    super.key,
    required this.onMenuPressed,
    this.onSearchPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AppBarMenu> createState() => _AppBarMenuState();
}

class _AppBarMenuState extends State<AppBarMenu> {
  final GlobalKey _cartIconKey = GlobalKey();
  OverlayEntry? _cartOverlay;

  @override
  void dispose() {
    _removeCartOverlay();
    super.dispose();
  }

  void _removeCartOverlay() {
    _cartOverlay?.remove();
    _cartOverlay = null;
  }

  void _toggleCartMenu() {
    if (_cartOverlay != null) {
      _removeCartOverlay();
    } else {
      _openCartMenu();
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
      final menuH = healthDp(context, 96);
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

  @override
  Widget build(BuildContext context) {
    final logoHeight = healthDp(context, 26);
    final actionIconSize = healthDp(context, 20);
    final menuIconSize = healthDp(context, 24);

    ButtonStyle noHoverStyle() => ButtonStyle(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        );

    return AppBar(
      leading: IconButton(
        style: noHoverStyle(),
        icon: Icon(Icons.menu, color: Colors.black, size: menuIconSize),
        onPressed: widget.onMenuPressed,
      ),
      title: SvgPicture.asset(
        AppAssets.bomioraAppbarLogo,
        height: logoHeight,
        fit: BoxFit.contain,
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          onPressed: () {
            if (widget.onSearchPressed != null) {
              widget.onSearchPressed!();
            } else {
              SearchPopup.show(context);
            }
          },
          style: noHoverStyle(),
          icon: SvgPicture.asset(
            AppAssets.appbarSearchIcon,
            width: actionIconSize,
            height: actionIconSize,
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationCenterScreen(),
              ),
            );
          },
          style: noHoverStyle(),
          icon: SvgPicture.asset(
            AppAssets.appbarAlarmIcon,
            width: actionIconSize,
            height: actionIconSize,
          ),
        ),
        IconButton(
          key: _cartIconKey,
          onPressed: _toggleCartMenu,
          style: noHoverStyle(),
          icon: SvgPicture.asset(
            AppAssets.appbarCartIcon,
            width: actionIconSize,
            height: actionIconSize,
          ),
        ),
        SizedBox(width: healthDp(context, 6)),
      ],
    );
  }
}
