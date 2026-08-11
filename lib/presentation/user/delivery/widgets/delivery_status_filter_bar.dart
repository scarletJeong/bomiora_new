import 'package:flutter/material.dart';

import '../../../common/widgets/web_dragscroll.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 주문 유형: 비대면 진료 / 일반상품
class DeliveryProductType {
  static const prescription = 'prescription';
  static const general = 'general';
}

/// 주문 목록 상단 — 상품유형 + 배송/주문 상태 필터
class DeliveryStatusFilterBar extends StatefulWidget {
  const DeliveryStatusFilterBar({
    super.key,
    required this.selectedProductType,
    required this.onProductTypeSelected,
    required this.selectedKey,
    required this.onSelected,
  });

  final String selectedProductType;
  final ValueChanged<String> onProductTypeSelected;
  final String selectedKey;
  final ValueChanged<String> onSelected;

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

  @override
  State<DeliveryStatusFilterBar> createState() =>
      _DeliveryStatusFilterBarState();
}

class _DeliveryStatusFilterBarState extends State<DeliveryStatusFilterBar> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kTabBorder = Color(0xFFD2D2D2);

  late String _productType;
  late String _statusKey;

  @override
  void initState() {
    super.initState();
    _productType = widget.selectedProductType;
    _statusKey = widget.selectedKey;
  }

  @override
  void didUpdateWidget(covariant DeliveryStatusFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모 prop이 바뀔 때만 동기화 (낙관적 로컬 선택을 덮어쓰지 않음)
    if (widget.selectedProductType != oldWidget.selectedProductType) {
      _productType = widget.selectedProductType;
    }
    if (widget.selectedKey != oldWidget.selectedKey) {
      _statusKey = widget.selectedKey;
    }
  }

  void _selectProductType(String key) {
    if (_productType == key) return;
    setState(() {
      _productType = key;
      _statusKey = 'all';
    });
    widget.onProductTypeSelected(key);
  }

  void _selectStatus(String key) {
    if (_statusKey == key) return;
    setState(() => _statusKey = key);
    widget.onSelected(key);
  }

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 27);
    final tabGap = healthDp(context, 12);
    // 로컬 유형 기준 — 탭 전환 직후 부모 리빌드 전에도 칩 목록이 바로 바뀜
    final entries = _productType == DeliveryProductType.general
        ? DeliveryStatusFilterBar.generalStatusEntries
        : DeliveryStatusFilterBar.prescriptionStatusEntries;

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
              healthDp(context, 16),
              padH,
              healthDp(context, 16),
            ),
            child: WebDragScrollConfiguration(
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) SizedBox(width: tabGap),
                        _statusChip(
                          context,
                          entries[i].key,
                          entries[i].value,
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
    final selected = _productType == key;
    final textLineGap = healthDp(context, 10);
    final underlineH = healthDp(context, 2);

    return GestureDetector(
      onTap: () => _selectProductType(key),
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

  /// 선택 시에도 글자 크기 고정 (12)
  Widget _statusChip(BuildContext context, String key, String label) {
    final selected = _statusKey == key;
    final padH = healthDp(context, 10);
    final padV = healthDp(context, 2);

    return GestureDetector(
      onTap: () => _selectStatus(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: selected
            ? ShapeDecoration(
                color: _kPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 20)),
                ),
              )
            : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: selected ? Colors.white : _kMuted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
