import 'package:flutter/material.dart';

import '../../../common/widgets/web_dragscroll.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 주문 유형: 비대면 진료 / 일반상품
class DeliveryProductType {
  static const prescription = 'prescription';
  static const general = 'general';
}

/// 주문 목록 상단 — 상품유형 + 배송/주문 상태 필터
class DeliveryStatusFilterBar extends StatelessWidget {
  const DeliveryStatusFilterBar({
    super.key,
    required this.selectedProductType,
    required this.onProductTypeSelected,
    required this.selectedKey,
    required this.onSelected,
    required this.statusEntries,
  });

  final String selectedProductType;
  final ValueChanged<String> onProductTypeSelected;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final List<MapEntry<String, String>> statusEntries;

  static const List<MapEntry<String, String>> prescriptionStatusEntries = [
    MapEntry('all', '전체'),
    MapEntry('payment_waiting', '결제대기중'),
    MapEntry('paid', '결제완료'),
    MapEntry('consultation_done', '상담완료'),
    MapEntry('delivering', '배송중'),
    MapEntry('completed', '배송완료'),
    MapEntry('cancelled', '주문취소'),
  ];

  static const List<MapEntry<String, String>> generalStatusEntries = [
    MapEntry('all', '전체'),
    MapEntry('payment_waiting', '결제대기중'),
    MapEntry('paid', '결제완료'),
    MapEntry('preparing', '배송준비중'),
    MapEntry('delivering', '배송중'),
    MapEntry('completed', '배송완료'),
    MapEntry('cancelled', '주문취소'),
  ];

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kTabBorder = Color(0xFFD2D2D2);

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 27);
    final tabGap = healthDp(context, 8);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(width: 1, color: _kTabBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _productTypeTab(
                    context,
                    key: DeliveryProductType.prescription,
                    label: '비대면진료',
                  ),
                ),
                Expanded(
                  child: _productTypeTab(
                    context,
                    key: DeliveryProductType.general,
                    label: '일반상품',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padH,
              healthDp(context, 12),
              padH,
              healthDp(context, 12),
            ),
            child: WebDragScrollConfiguration(
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < statusEntries.length; i++) ...[
                        if (i > 0) SizedBox(width: tabGap),
                        _statusChip(
                          context,
                          statusEntries[i].key,
                          statusEntries[i].value,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTypeTab(
    BuildContext context, {
    required String key,
    required String label,
  }) {
    final selected = selectedProductType == key;
    final textLineGap = healthDp(context, 10);
    final underlineH = healthDp(context, 2);

    return GestureDetector(
      onTap: () => onProductTypeSelected(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: healthDp(context, 10)),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? _kPink : _kMuted,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1,
              ),
            ),
            SizedBox(height: textLineGap),
            Container(
              width: double.infinity,
              height: underlineH,
              color: selected ? _kPink : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  /// content_list_screen 탭 칩과 동일 스타일
  Widget _statusChip(BuildContext context, String key, String label) {
    final selected = selectedKey == key;

    if (selected) {
      return GestureDetector(
        onTap: () => onSelected(key),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 2),
          ),
          decoration: ShapeDecoration(
            color: _kPink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 20)),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onSelected(key),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: healthDp(context, 3)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
