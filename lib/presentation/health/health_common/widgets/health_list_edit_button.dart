import 'package:flutter/material.dart';

import 'package:bomiora_app/presentation/health/health_common/health_responsive_scale.dart';

/// 체중 목록 등에서 쓰는 **수정하기** 칩 (375 기준: 패딩 5, 모서리 10, 글자 8sp).
///
/// 혈압·혈당·생리주기 목록과 동일 스펙으로 통일할 때 사용.
class HealthListEditButton extends StatelessWidget {
  const HealthListEditButton({
    super.key,
    required this.onTap,
    this.label = '수정하기',
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = healthDp(context, 10);
    final pad = healthDp(context, 5);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r),
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5A8D),
          borderRadius: BorderRadius.circular(r),
        ),
        child: Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.white,
            fontSize: healthSp(context, 8),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
