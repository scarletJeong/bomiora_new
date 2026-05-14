import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../health_responsive_scale.dart';

/// 건강 그래프 카드 우측 상단 확대 아이콘 + '확대' 라벨.
class HealthChartExpandControl extends StatelessWidget {
  const HealthChartExpandControl({
    super.key,
    required this.onTap,
    required this.iconSize,
  });

  final VoidCallback onTap;
  final double iconSize;

  /// 논리 크기 8 — 상위 [MediaQuery.textScaler]로 확대.
  static TextStyle labelTextStyle(BuildContext context) => const TextStyle(
        color: Color(0xFFF17E9D),
        fontSize: 8,
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w300,
        height: 1.0,
      );

  /// [Positioned.top] 보정용: 아이콘만 쓸 때의 `iconSize/2` 대신 블록 중앙 정렬에 사용.
  static double blockHeight(BuildContext context, double iconSize) {
    final gap = healthDp(context, 2);
    final labelH = MediaQuery.textScalerOf(context).scale(8) * 1.15;
    return iconSize + gap + labelH;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.healthZoomin,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
          SizedBox(height: healthDp(context, 2)),
          Text(
            '확대',
            style: labelTextStyle(context),
          ),
        ],
      ),
    );
  }
}
