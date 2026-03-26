import 'package:flutter/material.dart';

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
    MapEntry('all', '전체내역'),
    MapEntry('payment_waiting', '결제대기중'),
    MapEntry('preparing', '배송준비중'),
    MapEntry('delivering', '배송중'),
    MapEntry('completed', '배송완료'),
    MapEntry('exchange', '교환중'),
    MapEntry('refund', '환불중'),
    MapEntry('cancelled', '주문 취소'),
  ];

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kMuted = Color(0xFF898686);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < statusEntries.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              _tab(statusEntries[i].key, statusEntries[i].value),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(String key, String label) {
    final selected = selectedKey == key;
    return GestureDetector(
      onTap: () => onSelected(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: selected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(width: 1, color: _kPink),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _kPink : _kMuted,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
