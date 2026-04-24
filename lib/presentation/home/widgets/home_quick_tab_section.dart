import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';

class HomeQuickTabSection extends StatelessWidget {
  const HomeQuickTabSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 10,
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
    return Container(
      width: 1,
      height: 26,
      color: const Color(0xFFE5E5E5),
    );
  }
}
