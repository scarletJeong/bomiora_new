import 'package:flutter/material.dart';

import '../../../common/widgets/app_bar_menu.dart';
import '../health_responsive_scale.dart';

/// 로고 앱바 우측 액션: 홈(검색·알림·장바구니) / 마이페이지(장바구니·설정)
enum HealthAppBarActionsStyle { home, myPage }

enum _HealthAppBarVariant { back, logo }

/// 앱 전역 공통 AppBar.
/// 375 기준 높이 [healthAppBarTotalHeightBase](52).
/// 뒤로가기: 제목은 버튼 오른쪽 왼쪽 정렬 / 로고: [HealthAppBar.logo].
class HealthAppBar extends StatelessWidget
    implements HealthResponsivePreferredSizeWidget {
  static const double toolbarHeightBase = healthAppBarTotalHeightBase;

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final double? titleFontSize;
  final double? leadingIconSize;
  final PreferredSizeWidget? bottom;
  final bool showLeading;

  final _HealthAppBarVariant _variant;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSearchPressed;
  final HealthAppBarActionsStyle actionsStyle;

  const HealthAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.titleFontSize,
    this.leadingIconSize,
    this.bottom,
    this.showLeading = true,
  })  : _variant = _HealthAppBarVariant.back,
        onMenuPressed = null,
        onSearchPressed = null,
        actionsStyle = HealthAppBarActionsStyle.home;

  /// 햄버거 + 가운데 로고 + 홈/마이페이지 액션.
  const HealthAppBar.logo({
    super.key,
    required this.onMenuPressed,
    this.onSearchPressed,
    this.actionsStyle = HealthAppBarActionsStyle.home,
    this.bottom,
  })  : _variant = _HealthAppBarVariant.logo,
        title = '',
        actions = null,
        onBack = null,
        titleFontSize = null,
        leadingIconSize = null,
        showLeading = true;

  @override
  Size get preferredSize => healthAppBarPreferredSize(
        bottomHeight: bottom?.preferredSize.height ?? 0,
      );

  @override
  Size preferredSizeForWidth(double width) => healthAppBarPreferredSize(
        width: width,
        bottomHeight: bottom?.preferredSize.height ?? 0,
      );

  @override
  Widget build(BuildContext context) {
    if (_variant == _HealthAppBarVariant.logo) {
      return AppBarMenu(
        onMenuPressed: onMenuPressed!,
        onSearchPressed: onSearchPressed,
        actionsStyle: actionsStyle == HealthAppBarActionsStyle.myPage
            ? AppBarMenuActionsStyle.myPage
            : AppBarMenuActionsStyle.home,
      );
    }
    return _buildBackBar(context);
  }

  Widget _buildBackBar(BuildContext context) {
    final barH = healthAppBarTotalHeight(context);
    final iconSize = (leadingIconSize ?? healthDp(context, 24)).clamp(0.0, barH);
    final leadingSlot = healthDp(context, 40);
    final titleGap = healthDp(context, 4);

    final titleWidget = Text(
      title,
      textScaler: TextScaler.noScaling,
      textAlign: TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        color: Colors.black,
        fontSize: titleFontSize ?? healthSp(context, 16),
        height: 1,
      ),
    );

    return healthAppBarChrome(
      context: context,
      bottom: bottom,
      toolbar: Padding(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 5)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showLeading)
              SizedBox(
                width: leadingSlot,
                height: barH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack ?? () => Navigator.pop(context),
                  child: Center(
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.black,
                      size: iconSize,
                    ),
                  ),
                ),
              )
            else
              SizedBox(width: leadingSlot, height: barH),
            SizedBox(width: titleGap),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: titleWidget,
              ),
            ),
            if (actions != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: actions!,
              )
            else
              SizedBox(width: leadingSlot, height: barH),
          ],
        ),
      ),
    );
  }
}

/// Scaffold 슬롯과 맞춘 고정 높이 셸 (뒤로가기·로고 앱바 공통).
Widget healthAppBarChrome({
  required BuildContext context,
  required Widget toolbar,
  PreferredSizeWidget? bottom,
}) {
  final topInset = healthStatusBarTopInset(context);
  final barH = healthAppBarTotalHeight(context);
  final bottomH = bottom?.preferredSize.height ?? 0;
  return SizedBox(
    height: barH + topInset + bottomH,
    width: double.infinity,
    child: Material(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: barH,
              width: double.infinity,
              child: toolbar,
            ),
          ),
          if (bottom != null) bottom,
        ],
      ),
    ),
  );
}

/// [HealthAppBar.actions]용 아이콘 버튼 (호버/스플래시 없음).
Widget healthAppBarAction({
  required BuildContext context,
  required IconData icon,
  VoidCallback? onPressed,
  String? tooltip,
  Color iconColor = Colors.black,
}) {
  final barH = healthAppBarTotalHeight(context);
  return SizedBox(
    height: barH,
    child: IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: Size(barH, barH),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: iconColor,
        size: healthDp(context, 24).clamp(0.0, barH),
      ),
    ),
  );
}
