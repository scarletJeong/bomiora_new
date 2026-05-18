import 'package:flutter/material.dart';

import '../health_responsive_scale.dart';

/// 건강 화면 공통 AppBar (뒤로가기, 제목, 선택적 액션)
class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  /// null이면 375 기준 16 ([healthSp]). [MobileAppLayoutWrapper] 바깥에서도 제목 스케일을 맞출 때 사용.
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // chevron: leading 56 가운데 유지. titleSpacing 음수로 제목만 더 왼쪽.
    final iconSize = leadingIconSize ?? healthDp(context, 24);
    final leadingSlot = healthDp(context, 56);
    final iconRight = (leadingSlot - iconSize) / 2 + iconSize;
    final chevronToTitleGap = healthDp(context, 4);
    final titleSpacing = iconRight + chevronToTitleGap - leadingSlot;

    return AppBar(
      titleSpacing: titleSpacing,
      leading: IconButton(
        icon: Icon(
          Icons.chevron_left,
          color: Colors.black,
          size: leadingIconSize,
        ),
        onPressed: onBack ?? () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: titleFontSize ?? healthSp(context, 16),
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
