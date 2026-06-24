import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../settings/notification_center_screen.dart';
import '../../shopping/screens/cart_general_screen.dart' as cart_general;
import '../../home/search/search_popup.dart';
import 'cart_dropdown_menu.dart';

/// [HealthAppBar]와 동일한 전체 높이(375 기준 48).
/// 아이콘·로고는 48 높이 안에서 세로 중앙 배치.
/// 좌우 패딩 `5`, 좌측 메뉴·우측 액션 아이콘 `19.82`, 액션 당김(겹침) `12`,
/// 로고는 패딩 안 전체 폭 기준 [Stack] + [Center]로 **화면 가로 정중앙**.
/// 모든 길이·간격은 [healthDp] / [healthAppBarTotalHeight]로 스케일합니다.
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
  Size get preferredSize {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return Size.fromHeight(healthAppBarTotalHeightForWidth(375));
    }
    final v = views.first;
    final logicalW = v.physicalSize.width / v.devicePixelRatio;
    return Size.fromHeight(healthAppBarTotalHeightForWidth(logicalW));
  }

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
    required double iconSz,
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
            child: SizedBox(
              width: iconSz,
              height: iconSz,
              child: Icon(Icons.menu, color: Colors.black, size: iconSz),
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
          child: Align(
            alignment: Alignment.center,
            child: SvgPicture.asset(
              asset,
              width: iconSz,
              height: iconSz,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barH = healthAppBarTotalHeight(context);
    final padH = healthDp(context, 5);
    final iconSz = healthDp(context, 19.82);
    /// [Row.spacing]은 0 이상만 허용. 예전 음수 간격과 같은 밀도는 `Stack`으로 겹침 배치.
    final actionOverlap = healthDp(context, 12);
    final logoW = healthDp(context, 99.09);
    final logoH = healthDp(context, 20);
    final tapBoxW = math.max(iconSz, healthDp(context, 40));

    final actionStep = math.max(4.0, tapBoxW - actionOverlap);
    final actionsWidth = tapBoxW + 2 * actionStep;

    return SizedBox(
      height: barH,
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
            padding: EdgeInsets.symmetric(horizontal: padH),
            child: SizedBox(
              height: barH,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _leadingMenu(
                          width: tapBoxW,
                          height: barH,
                          iconSz: iconSz,
                          onPressed: widget.onMenuPressed,
                        ),
                        const Spacer(),
                        SizedBox(
                          height: barH,
                          width: actionsWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                height: barH,
                                width: tapBoxW,
                                child: _actionSvg(
                                  asset: AppAssets.appbarSearchIcon,
                                  width: tapBoxW,
                                  height: barH,
                                  iconSz: iconSz,
                                  onPressed: () {
                                    if (widget.onSearchPressed != null) {
                                      widget.onSearchPressed!();
                                    } else {
                                      SearchPopup.show(context);
                                    }
                                  },
                                ),
                              ),
                              Positioned(
                                left: actionStep,
                                top: 0,
                                height: barH,
                                width: tapBoxW,
                                child: _actionSvg(
                                  asset: AppAssets.appbarAlarmIcon,
                                  width: tapBoxW,
                                  height: barH,
                                  iconSz: iconSz,
                                  onPressed: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const NotificationCenterScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                left: 2 * actionStep,
                                top: 0,
                                height: barH,
                                width: tapBoxW,
                                child: _actionSvg(
                                  key: _cartIconKey,
                                  asset: AppAssets.appbarCartIcon,
                                  width: tapBoxW,
                                  height: barH,
                                  iconSz: iconSz,
                                  onPressed: _toggleCartMenu,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.center,
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
    );
  }
}
