import 'package:flutter/material.dart';

enum HealthAppBarLeadingType { back, menu }

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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isMenu = leadingType == HealthAppBarLeadingType.menu;
    return AppBar(
      leading: IconButton(
        icon: Icon(isMenu ? Icons.menu : Icons.chevron_left, color: Colors.black),
        onPressed: onBack ?? () => Navigator.maybePop(context),
      ),
      title: centerTitle
          ? Text(
              title,
              style: const TextStyle(
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontSize: 18,
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
