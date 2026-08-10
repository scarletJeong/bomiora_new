import 'package:flutter/material.dart';

import '../../../../data/models/delivery/delivery_model.dart';
import '../../../health/health_common/health_responsive_scale.dart';

/// 주문 상품을 `it_subject`(업체/브랜드) 기준으로 묶습니다. 등장 순서를 유지합니다.
List<MapEntry<String, List<OrderItem>>> groupOrderItemsByItSubject(
  List<OrderItem> items,
) {
  final map = <String, List<OrderItem>>{};
  final keys = <String>[];
  for (final item in items) {
    final key = item.itSubject.trim();
    if (!map.containsKey(key)) {
      keys.add(key);
      map[key] = <OrderItem>[];
    }
    map[key]!.add(item);
  }
  return [for (final k in keys) MapEntry(k, map[k]!)];
}

String orderItemDisplayTitle(OrderItem item) {
  final name = item.itName.trim();
  if (name.isNotEmpty) return name;
  final subject = item.itSubject.trim();
  if (subject.isNotEmpty) return subject;
  return '상품명 없음';
}

String _normalizeOptionToken(String s) =>
    s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// `ct_option`이 상품명과 같거나(옵션 없는 단품이 이름을 옵션에 넣는 경우)
/// 실질 옵션이 없으면 수량만 반환합니다.
List<String> filterOptionPartsAgainstTitle({
  required String title,
  required String rawOption,
}) {
  final parts = rawOption
      .split(RegExp(r'\s*/\s*|\s*ㅣ\s*|\s*\|\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return const [];

  final titleNorm = _normalizeOptionToken(title);
  if (titleNorm.isEmpty) return parts;

  return parts.where((p) {
    final n = _normalizeOptionToken(p);
    if (n.isEmpty) return false;
    // 옵션 토큰 == 상품명 (완전 동일)
    if (n == titleNorm) return false;
    // 옵션 전체가 상품명과 동일하게 붙어 있는 경우
    if (parts.length == 1 &&
        (n.contains(titleNorm) || titleNorm.contains(n)) &&
        (n.length - titleNorm.length).abs() <= 2) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

String orderItemQtyOptionLine(OrderItem item) {
  final raw = (item.ctOption ?? '').trim();
  if (raw.isEmpty) return '수량: ${item.ctQty}';
  final parts = filterOptionPartsAgainstTitle(
    title: orderItemDisplayTitle(item),
    rawOption: raw,
  );
  if (parts.isEmpty) return '수량: ${item.ctQty}';
  return '수량: ${item.ctQty} ㅣ ${parts.join(' ㅣ ')}';
}

/// 제목·옵션 줄 수 규칙:
/// - 옵션은 최대 2줄
/// - 제목·옵션이 둘 다 2줄이면 제목은 1줄(...)로 축소
class OrderItemTitleOptionBlock extends StatelessWidget {
  const OrderItemTitleOptionBlock({
    super.key,
    required this.title,
    required this.qtyOptionLine,
    required this.titleStyle,
    required this.optionStyle,
    this.gap = 5,
  });

  final String title;
  final String qtyOptionLine;
  final TextStyle titleStyle;
  final TextStyle optionStyle;
  final double gap;

  int _lineCount(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty || maxWidth <= 0) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return painter.computeLineMetrics().length.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final titleLines = _lineCount(title, titleStyle, maxW);
        final optionLines = _lineCount(qtyOptionLine, optionStyle, maxW);
        final titleMaxLines =
            (titleLines >= 2 && optionLines >= 2) ? 1 : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: titleStyle,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: healthDp(context, gap)),
            Text(
              qtyOptionLine,
              style: optionStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

bool orderItemIsSupplyAdd(OrderItem item) {
  final p = (item.parent ?? '').trim();
  if (p.isNotEmpty) return true;
  final kind = (item.ctKind ?? '').trim().toLowerCase();
  return kind.startsWith('supply_add|');
}

String? orderItemParentItId(OrderItem item) {
  final p = (item.parent ?? '').trim();
  if (p.isNotEmpty) return p;
  final kind = (item.ctKind ?? '').trim();
  const prefix = 'supply_add|';
  if (!kind.toLowerCase().startsWith(prefix)) return null;
  final id = kind.substring(prefix.length).trim();
  return id.isEmpty ? null : id;
}

/// 본품 + 추가상품(supply_add) 묶음. 등장 순서 유지.
class OrderSupplyGroup {
  const OrderSupplyGroup({
    required this.parent,
    this.children = const [],
  });

  final OrderItem parent;
  final List<OrderItem> children;
}

List<OrderSupplyGroup> groupOrderItemsWithSupply(List<OrderItem> items) {
  if (items.isEmpty) return const [];

  final used = <int>{};
  final childrenByParentItId = <String, List<OrderItem>>{};

  for (final item in items) {
    if (!orderItemIsSupplyAdd(item)) continue;
    final parentId = orderItemParentItId(item);
    if (parentId == null) continue;
    childrenByParentItId.putIfAbsent(parentId, () => []).add(item);
    used.add(item.ctId);
  }

  final groups = <OrderSupplyGroup>[];
  for (final item in items) {
    if (used.contains(item.ctId)) continue;
    if (orderItemIsSupplyAdd(item)) {
      // 부모를 못 찾은 orphan 추가상품 — 단독 노출
      groups.add(OrderSupplyGroup(parent: item));
      used.add(item.ctId);
      continue;
    }
    final kids = List<OrderItem>.unmodifiable(
      childrenByParentItId[item.itId.trim()] ?? const <OrderItem>[],
    );
    for (final c in kids) {
      used.add(c.ctId);
    }
    groups.add(OrderSupplyGroup(parent: item, children: kids));
    used.add(item.ctId);
  }
  return groups;
}
