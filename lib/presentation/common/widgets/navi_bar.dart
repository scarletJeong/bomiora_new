import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 하단 가로 바 ↔ 오른쪽 세로 바 전환 기준 (px).
const double kFooterBarWideBreakpoint = 950;

/// 공통으로 쓰는 하단 핑크 탭 바 (Figma)
///
/// - 파일명만 `footer_bar.dart` → `navi_bar.dart`로 변경했습니다.
/// - 기존 사용처가 많아서 클래스명(`FooterBar`)은 유지합니다.
/// - [kFooterBarWideBreakpoint] 이상에서는 빈 위젯을 반환하고 [SideNaviBar]를 레이아웃 래퍼에서 표시합니다.
/// - 수치는 모두 [healthDp]/[healthSp]로 375~650 폭 기준 스케일 적용.
class FooterBar extends StatelessWidget {
  const FooterBar({super.key});

  static const Color _pink = Color(0xFFFF5A8D);

  Widget _sep(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
      child: Text(
        '|',
        style: TextStyle(
          color: const Color(0xCCFFFFFF),
          fontSize: healthSp(context, 10),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
          height: 1,
        ),
      ),
    );
  }

  void _go(BuildContext context, String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) return;
    Navigator.pushNamed(context, routeName);
  }

  Widget _item({
    required BuildContext context,
    required String label,
    required String iconAsset,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
          child: Padding(
            padding: EdgeInsets.only(
              top: healthDp(context, 6),
              bottom: healthDp(context, 8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  iconAsset,
                  width: healthDp(context, 18),
                  height: healthDp(context, 18),
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                SizedBox(height: healthDp(context, 4.62)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 8),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth >= kFooterBarWideBreakpoint) {
      return const SizedBox.shrink();
    }

    final padH = healthDp(context, 10);
    final barH = healthDp(context, 62);
    final radius = healthDp(context, 15);

    return Container(
      width: double.infinity,
      height: barH,
      padding: EdgeInsets.symmetric(horizontal: padH),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: _pink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _item(
            context: context,
            label: 'HOME',
            iconAsset: AppAssets.naviIcon1,
            onTap: () => _go(context, '/home'),
          ),
          _sep(context),
          _item(
            context: context,
            label: '건강대시보드',
            iconAsset: AppAssets.naviIcon2,
            onTap: () => _go(context, '/health'),
          ),
          _sep(context),
          _item(
            context: context,
            label: '비대면 진료',
            iconAsset: AppAssets.naviIcon3,
            onTap: null,
          ),
          _sep(context),
          _item(
            context: context,
            label: '문진표',
            iconAsset: AppAssets.naviIcon4,
            onTap: () => _go(context, '/profile'),
          ),
          _sep(context),
          _item(
            context: context,
            label: 'MY PAGE',
            iconAsset: AppAssets.naviIcon5,
            onTap: () => _go(context, '/my_page'),
          ),
        ],
      ),
    );
  }
}

/// 넓은 화면(≥950)에서 콘텐츠 패널 오른쪽에 표시하는 세로 핑크 네비 바.
///
/// Figma에서 950+ 레이아웃 기준으로 내려준 고정 px만 사용합니다. [healthDp]/[healthSp] 미사용.
class SideNaviBar extends StatelessWidget {
  const SideNaviBar({super.key});

  static const Color _pink = Color(0xFFFF5A8D);

  static const double _padH = 10;
  static const double _padV = 30;
  static const double _radius = 50.53;
  static const double _itemGap = 14;
  static const double _iconSize = 33;
  static const double _labelGap = 6.74;
  static const double _labelSize = 11;
  static const double _separatorWidth = 14;
  static const double _separatorHeight = 1;

  static const _items = <_SideNaviEntry>[
    _SideNaviEntry(label: 'HOME', icon: AppAssets.naviIcon1, route: '/home'),
    _SideNaviEntry(
      label: '건강대시보드',
      icon: AppAssets.naviIcon2,
      route: '/health',
    ),
    _SideNaviEntry(
      label: '비대면 진료',
      icon: AppAssets.naviIcon3,
      route: null,
    ),
    _SideNaviEntry(
      label: '문진표',
      icon: AppAssets.naviIcon4,
      route: '/profile',
    ),
    _SideNaviEntry(
      label: 'MY PAGE',
      icon: AppAssets.naviIcon5,
      route: '/my_page',
    ),
  ];

  void _go(BuildContext context, String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) return;
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: _padV),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: _pink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) _itemSeparator(),
            _sideItem(
              entry: _items[i],
              onTap: _items[i].route == null
                  ? null
                  : () => _go(context, _items[i].route!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemSeparator() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: _itemGap),
        SizedBox(
          width: _separatorWidth,
          height: _separatorHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white),
          ),
        ),
        SizedBox(height: _itemGap),
      ],
    );
  }

  Widget _sideItem({
    required _SideNaviEntry entry,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              entry.icon,
              width: _iconSize,
              height: _iconSize,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(height: _labelGap),
            Text(
              entry.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: _labelSize,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNaviEntry {
  final String label;
  final String icon;
  final String? route;

  const _SideNaviEntry({
    required this.label,
    required this.icon,
    required this.route,
  });
}
