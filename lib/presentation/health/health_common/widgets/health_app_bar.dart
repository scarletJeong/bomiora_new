import 'package:flutter/material.dart';

/// 건강 화면 공통 AppBar (뒤로가기, 제목, 선택적 액션)
class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  /// null이면 기본 18. [MobileAppLayoutWrapper] 바깥에서도 제목 스케일을 맞출 때 사용.
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
    return AppBar(
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
          fontSize: titleFontSize ?? 18,
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
