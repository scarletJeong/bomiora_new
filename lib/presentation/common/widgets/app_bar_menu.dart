import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../settings/notification_center_screen.dart';
import '../../shopping/screens/cart_general_screen.dart' as cart_general;
import '../../home/search/search_popup.dart';
import 'cart_dropdown_menu.dart';

/// Figma **375**: 전체 `66.92` × 가로, 좌우 패딩 `26.75`·세로 `23.78`(콘텐츠 높이와 맞게 보정 가능),
/// 좌측 메뉴·우측 액션 아이콘 `19.82`, 액션 당김(겹침) `12`(375 기준, 예전 `Row.spacing: -12`와 같은 밀도 — [Row]는 음수 간격 불가라 [Stack]으로 구현),
/// 로고는 패딩 안 전체 폭 기준 [Stack] + [Center]로 **화면 가로 정중앙** (좌 `tapBox` ≠ 우 `actionsWidth`여도 유지).
/// 모든 길이·간격은 [healthDp]로 스케일합니다.
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
    if (views.isEmpty) return const Size.fromHeight(66.92);
    final v = views.first;
    final logicalW = v.physicalSize.width / v.devicePixelRatio;
    return Size.fromHeight(66.92 * healthTextScaleByWidth(logicalW));
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
    required double iconBox,
    required double iconSz,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: iconBox,
      height: iconBox,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child: Icon(Icons.menu, color: Colors.black, size: iconSz),
        ),
      ),
    );
  }

  Widget _actionSvg({
    Key? key,
    required String asset,
    required VoidCallback onPressed,
    required double iconBox,
    required double iconSz,
  }) {
    return SizedBox(
      key: key,
      width: iconBox,
      height: iconBox,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child: SvgPicture.asset(
            asset,
            width: iconSz,
            height: iconSz,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barH = healthDp(context, 66.92);
    final padH = healthDp(context, 5);
    final padVFigma = healthDp(context, 23.78);
    final iconSz = healthDp(context, 19.82);
    /// [Row.spacing]은 0 이상만 허용. 예전 음수 간격과 같은 밀도는 `Stack`으로 겹침 배치.
    final actionOverlap = healthDp(context, 12);
    final logoW = healthDp(context, 99.09);
    // Figma 21.06보다 살짝 작게
    final logoH = healthDp(context, 20);
    final tapBox = math.max(iconSz, healthDp(context, 40));

    final innerH = barH - 2 * padVFigma;
    final padV = innerH >= iconSz
        ? padVFigma
        : math.max(0.0, (barH - math.max(iconSz, logoH)) / 2);

    final actionStep = math.max(4.0, tapBox - actionOverlap);
    final actionsWidth = tapBox + 2 * actionStep;

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
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: IntrinsicHeight(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _leadingMenu(
                        iconBox: tapBox,
                        iconSz: iconSz,
                        onPressed: widget.onMenuPressed,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: actionsWidth,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: tapBox,
                              child: _actionSvg(
                                asset: AppAssets.appbarSearchIcon,
                                iconBox: tapBox,
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
                              bottom: 0,
                              width: tapBox,
                              child: _actionSvg(
                                asset: AppAssets.appbarAlarmIcon,
                                iconBox: tapBox,
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
                              bottom: 0,
                              width: tapBox,
                              child: _actionSvg(
                                key: _cartIconKey,
                                asset: AppAssets.appbarCartIcon,
                                iconBox: tapBox,
                                iconSz: iconSz,
                                onPressed: _toggleCartMenu,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
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
