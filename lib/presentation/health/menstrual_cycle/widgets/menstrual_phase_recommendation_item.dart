import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../data/models/health/menstrual_cycle/menstrual_cycle_model.dart';
import '../../health_common/health_responsive_scale.dart';
import '../utils/menstrual_phase_link.dart';

class MenstrualPhaseRecommendationItem extends StatelessWidget {
  const MenstrualPhaseRecommendationItem({
    super.key,
    required this.tip,
    this.compact = true,
  });

  final MenstrualPhaseTip tip;
  final bool compact;

  String get _iconAsset {
    return tip.label == MenstrualPhaseTip.bomioraPickLabel
        ? AppAssets.menstrualBomioraPickIcon
        : AppAssets.menstrualConditionCheckIcon;
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? healthDp(context, 20) : 20.0;
    final gap = compact ? healthDp(context, 12) : 12.0;
    final labelFs = compact ? healthSp(context, 12) : 13.0;
    final messageFs = compact ? healthSp(context, 12) : 13.0;
    final chevronSize = compact ? healthDp(context, 18) : 18.0;

    final isBomioraPick = tip.label == MenstrualPhaseTip.bomioraPickLabel;
    final messageColor =
        isBomioraPick && tip.isTappable ? const Color(0xFFFF5A8D) : Colors.black;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: SvgPicture.asset(
            _iconAsset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => SizedBox(
              width: iconSize,
              height: iconSize,
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: labelFs,
                  color: Colors.black,
                  height: 1.4,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? healthDp(context, 4) : 4),
              Text(
                tip.message,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: messageFs,
                  color: messageColor,
                  height: 1.4,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        if (tip.isTappable) ...[
          SizedBox(width: compact ? healthDp(context, 4) : 4),
          Icon(
            Icons.chevron_right,
            size: chevronSize,
            color: const Color(0xFFFF5A8D),
          ),
        ],
      ],
    );

    if (!tip.isTappable) return content;

    return InkWell(
      onTap: () => navigateMenstrualPhaseLink(context, tip.linkTarget),
      borderRadius: BorderRadius.circular(compact ? healthDp(context, 8) : 8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? healthDp(context, 2) : 2,
        ),
        child: content,
      ),
    );
  }
}
