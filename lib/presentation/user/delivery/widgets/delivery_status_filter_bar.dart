import 'package:flutter/material.dart';

import '../../../common/widgets/web_dragscroll.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 주문 목록 상단 — 배송/주문 상태 필터 (가로 스크롤, `delivery_status` 키).
class DeliveryStatusFilterBar extends StatelessWidget {
  const DeliveryStatusFilterBar({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  final String selectedKey;
  final ValueChanged<String> onSelected;

  static const List<MapEntry<String, String>> statusEntries = [
    MapEntry('all', '전체'),
    MapEntry('payment_waiting', '결제대기중'),
    MapEntry('preparing', '배송준비중'),
    MapEntry('delivering', '배송중'),
    MapEntry('completed', '배송완료'),
    MapEntry('exchange', '교환'),
    MapEntry('refund', '환불'),
    MapEntry('cancelled', '주문 취소'),
  ];

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kMuted = Color(0xFF898686);

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 27);
    final padV = healthDp(context, 12);
    final tabGap = healthDp(context, 20);

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, tabGap, padH, 0),
        child: WebDragScrollConfiguration(
          child: ClipRect(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < statusEntries.length; i++) ...[
                    if (i > 0) SizedBox(width: tabGap),
                    _tab(context, statusEntries[i].key, statusEntries[i].value),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String key, String label) {
    final selected = selectedKey == key;
    final textLineGap = healthDp(context, 1);
    final underlineH = healthDp(context, 1);

    return GestureDetector(
      onTap: () => onSelected(key),
      behavior: HitTestBehavior.opaque,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: selected ? _kPink : _kMuted,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1,
              ),
            ),
            SizedBox(height: textLineGap),
            Container(
              height: underlineH,
              color: selected ? _kPink : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
