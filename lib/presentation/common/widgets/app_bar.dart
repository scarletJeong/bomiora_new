import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

enum HealthAppBarLeadingType { back, menu }

/// 375 기준 툴바 높이 56 — [healthTextScaleByWidth]와 동일 규칙.
double _healthAppBarToolbarHeight(double screenWidth) {
  return 56.0 * healthTextScaleByWidth(screenWidth);
}

/// 건강 화면 공통 AppBar (뒤로가기, 제목, 선택적 액션)
class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final HealthAppBarLeadingType leadingType;

  const HealthAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.actions,
    this.onBack,
    this.leadingType = HealthAppBarLeadingType.back,
  });

  @override
  Size get preferredSize {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return const Size.fromHeight(kToolbarHeight);
    final v = views.first;
    final logicalW = v.physicalSize.width / v.devicePixelRatio;
    return Size.fromHeight(_healthAppBarToolbarHeight(logicalW));
  }

  @override
  Widget build(BuildContext context) {
    final isMenu = leadingType == HealthAppBarLeadingType.menu;
    final iconSize = healthDp(context, 24);
    final titleFs = healthSp(context, 18);
    final toolbarH = _healthAppBarToolbarHeight(MediaQuery.sizeOf(context).width);

    return AppBar(
      toolbarHeight: toolbarH,
      leading: IconButton(
        iconSize: iconSize,
        icon: Icon(
          isMenu ? Icons.menu : Icons.chevron_left,
          color: Colors.black,
          size: iconSize,
        ),
        onPressed: onBack ?? () => Navigator.maybePop(context),
      ),
      title: centerTitle
          ? Text(
              title,
              style: TextStyle(
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: titleFs,
              ),
              textAlign: TextAlign.center,
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontSize: titleFs,
                ),
              ),
            ),
      centerTitle: centerTitle,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      actions: actions,
    );
  }
}
