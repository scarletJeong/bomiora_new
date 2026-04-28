import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../common/responsive_scale.dart';

class HomeQuickTabSection extends StatelessWidget {
  const HomeQuickTabSection({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rs.dp(20),
              vertical: rs.dp(14),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon1,
                    label: '비대면 진료',
                  ),
                ),
                _QuickDivider(),
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon2,
                    label: '문진표',
                  ),
                ),
                _QuickDivider(),
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon3,
                    label: '건강대시보드',
                  ),
                ),
                _QuickDivider(),
                Expanded(
                  child: _QuickTabItem(
                    iconAsset: AppAssets.quickTabIcon4,
                    label: '스토어',
                  ),
                ),
              ],
            ),
          ),
          // 아래 줄: 끝까지 꽉 채우지 않도록 좌우 여백 유지
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rs.dp(20)),
            child: const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E5E5),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTabItem extends StatelessWidget {
  final String iconAsset;
  final String label;

  const _QuickTabItem({
    required this.iconAsset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: rs.dp(24),
          height: rs.dp(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  iconAsset,
                  width: rs.dp(22),
                  height: rs.dp(22),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: rs.dp(6)),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: rs.sp(10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickDivider extends StatelessWidget {
  const _QuickDivider();

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Container(
      width: rs.dp(1),
      height: rs.dp(26),
      color: const Color(0xFFE5E5E5),
    );
  }
}
