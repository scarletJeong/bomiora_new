import 'package:flutter/material.dart';

import '../../../../health/health_common/health_responsive_scale.dart';

/// 주문 상세 섹션 공통 스타일
class DeliveryDetailSectionStyle {
  static const Color pink = Color(0xFFFF5A8D);
  static const Color border = Color(0x7FD2D2D2);
  static const Color muted = Color(0xFF898686);
  /// 진행바 미도달(남은) 상태 문구 — muted보다 연함
  static const Color mutedPending = Color(0xFFC8C8C8);
  static const Color mutedLabel = Color(0xFF898383);
  static const Color ink = Color(0xFF1A1A1E);
  static const Color inkAlt = Color(0xFF1A1A1A);
  static const String font = 'Gmarket Sans TTF';

  static ShapeDecoration cardDecoration(
    BuildContext context, {
    double radius = 15,
    Color? color,
  }) {
    return ShapeDecoration(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(width: healthDp(context, 1), color: border),
        borderRadius: BorderRadius.circular(healthDp(context, radius)),
      ),
    );
  }

  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: healthDp(context, 14),
      vertical: healthDp(context, 20),
    );
  }
}
