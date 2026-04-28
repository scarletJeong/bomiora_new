import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';

/// 햄버거 메뉴 + [AppAssets.bomioraAppbarLogo] + 선택적 액션. 뒤로가기(leading) 없음.
///
/// 툴바 높이·elevation/surfaceTint는 [HealthAppBar]와 유사하며 배경은 불투명 흰색입니다.
class AppBarMenu extends StatelessWidget implements PreferredSizeWidget {
  static const double _logoHeight = 26;
  static const double _actionIconSize = 20;

  final VoidCallback onMenuPressed;

  const AppBarMenu({
    super.key,
    required this.onMenuPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    ButtonStyle noHoverStyle() => ButtonStyle(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        );

    return AppBar(
      leading: IconButton(
        style: noHoverStyle(),
        icon: const Icon(Icons.menu, color: Colors.black),
        onPressed: onMenuPressed,
      ),
      title: Image.asset(
        AppAssets.bomioraAppbarLogo,
        height: _logoHeight,
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
          onPressed: () {},
          style: noHoverStyle(),
          icon: SvgPicture.asset(
            AppAssets.appbarSearchIcon,
            width: _actionIconSize,
            height: _actionIconSize,
          ),
        ),
        IconButton(
          onPressed: () {},
          style: noHoverStyle(),
          icon: SvgPicture.asset(
            AppAssets.appbarAlarmIcon,
            width: _actionIconSize,
            height: _actionIconSize,
          ),
        ),
        IconButton(
          onPressed: () {},
          style: noHoverStyle(),
          icon: SvgPicture.asset(
            AppAssets.appbarCartIcon,
            width: _actionIconSize,
            height: _actionIconSize,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}
