import 'package:flutter/material.dart';

/// 건강 화면 공통 AppBar (뒤로가기, 제목, 선택적 액션)
class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const HealthAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.actions,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: Colors.black),
        onPressed: onBack ?? () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      actions: actions,
    );
  }
}
