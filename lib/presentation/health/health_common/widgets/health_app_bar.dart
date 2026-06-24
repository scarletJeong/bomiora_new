import 'package:flutter/material.dart';

import '../health_responsive_scale.dart';

/// 건강 화면 공통 AppBar (뒤로가기, 제목, 선택적 액션).
/// 375 기준 전체 높이 52, 아이콘·제목은 높이 안에서 세로 중앙.
class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double toolbarHeightBase = 52;

  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  /// null이면 375 기준 16 ([healthSp]).
  final double? titleFontSize;

  /// null이면 기본 아이콘 크기.
  final double? leadingIconSize;

  const HealthAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.actions,
    this.onBack,
    this.titleFontSize,
    this.leadingIconSize,
  });

  @override
  Size get preferredSize {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return Size.fromHeight(healthAppBarTotalHeightForWidth(375));
    }
    final view = views.first;
    final physicalW = view.physicalSize.width;
    final dpr = view.devicePixelRatio;
    if (physicalW <= 0 ||
        dpr <= 0 ||
        !physicalW.isFinite ||
        !dpr.isFinite) {
      return Size.fromHeight(healthAppBarTotalHeightForWidth(375));
    }
    final logicalWidth = physicalW / dpr;
    return Size.fromHeight(healthAppBarTotalHeightForWidth(logicalWidth));
  }

  @override
  Widget build(BuildContext context) {
    final barH = healthAppBarTotalHeight(context);
    final iconSize = leadingIconSize ?? healthDp(context, 24);
    final leadingSlot = healthDp(context, 56);
    final iconRight = (leadingSlot - iconSize) / 2 + iconSize;
    final chevronToTitleGap = healthDp(context, 4);
    final titleSpacing = iconRight + chevronToTitleGap - leadingSlot;

    final titleWidget = Text(
      title,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w700,
        color: Colors.black,
        fontSize: titleFontSize ?? healthSp(context, 16),
        height: 1,
      ),
    );

    return AppBar(
      toolbarHeight: barH,
      leadingWidth: leadingSlot,
      titleSpacing: titleSpacing,
      leading: SizedBox(
        height: barH,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
          ),
          constraints: BoxConstraints(
            minWidth: leadingSlot,
            minHeight: barH,
          ),
          icon: Icon(
            Icons.chevron_left,
            color: Colors.black,
            size: iconSize,
          ),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
      ),
      title: SizedBox(
        height: barH,
        child: centerTitle
            ? Center(child: titleWidget)
            : Align(
                alignment: Alignment.centerLeft,
                child: titleWidget,
              ),
      ),
      centerTitle: centerTitle,
      actions: actions == null
          ? null
          : [
              SizedBox(
                height: barH,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: actions!,
                ),
              ),
            ],
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );
  }
}

/// [HealthAppBar.actions]용 아이콘 버튼 (호버/스플래시 없음).
Widget healthAppBarAction({
  required BuildContext context,
  required IconData icon,
  VoidCallback? onPressed,
  String? tooltip,
  Color iconColor = Colors.black,
}) {
  return IconButton(
    style: IconButton.styleFrom(
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
      size: healthDp(context, 24),
    ),
  );
}
