import 'cart_item_model.dart';

/// 장바구니 원상품 + 연결상품(supply_add) 묶음
class CartLineGroup {
  final CartItem parent;
  final List<CartItem> children;

  const CartLineGroup({
    required this.parent,
    this.children = const [],
  });

  int get groupAmount =>
      parent.lineAmount +
      children.fold<int>(0, (sum, c) => sum + c.lineAmount);

  List<CartItem> get allItems => [parent, ...children];

  static bool _csvContains(String? csv, String itId) {
    final id = itId.trim();
    if (id.isEmpty) return false;
    final raw = csv?.trim() ?? '';
    if (raw.isEmpty) return false;
    for (final part in raw.split(RegExp(r'[,|\s]+'))) {
      if (part.trim() == id) return true;
    }
    return false;
  }

  /// 평면 장바구니 목록을 부모-자식 그룹으로 묶습니다.
  ///
  /// 1) `parent`(부모 it_id)가 있으면 → 해당 본품 아래 (가능하면 같은 od_id)
  /// 2) legacy `ct_kind=supply_add|{parentItId}` (parent 컬럼 이관 전)
  /// 3) 같은 `od_id` + 부모 `it_supply_items` (호환)
  /// 4) od_id 없이 supply CSV fallback
  ///
  /// 매칭 키: (parent 유무, it_id, option) — 역방향 묶음은 공존.
  static List<CartLineGroup> groupItems(List<CartItem> items) {
    if (items.isEmpty) return const [];

    final used = <int>{};
    final childrenByParentCtId = <int, List<CartItem>>{};

    CartItem? _pickParent({
      required String parentItId,
      required String childOdId,
      bool preferPrescription = true,
    }) {
      final candidates = items
          .where(
            (p) =>
                !p.isSupplyAdd &&
                !used.contains(p.ctId) &&
                p.itId.trim() == parentItId,
          )
          .toList();
      if (candidates.isEmpty) return null;

      if (childOdId.isNotEmpty) {
        final sameOd = candidates
            .where((p) => p.odId.trim() == childOdId)
            .toList();
        if (sameOd.isNotEmpty) {
          if (preferPrescription) {
            final rx = sameOd.where((p) => p.isPrescription).toList();
            if (rx.isNotEmpty) return rx.first;
          }
          return sameOd.first;
        }
      }

      if (preferPrescription) {
        final rx = candidates.where((p) => p.isPrescription).toList();
        if (rx.isNotEmpty) return rx.first;
      }
      return candidates.first;
    }

    void _attach(CartItem parent, CartItem child) {
      childrenByParentCtId.putIfAbsent(parent.ctId, () => []).add(child);
      used.add(child.ctId);
    }

    // 1) 명시적 supply_add
    for (final item in items) {
      if (!item.isSupplyAdd) continue;
      final parentId = item.parentItId?.trim() ?? '';
      if (parentId.isEmpty) continue;
      final parent = _pickParent(
        parentItId: parentId,
        childOdId: item.odId.trim(),
      );
      if (parent == null) continue;
      _attach(parent, item);
    }

    // 2) 같은 od_id + 부모 it_supply_items (기존 general로 저장된 추가상품)
    for (final item in items) {
      if (used.contains(item.ctId)) continue;
      // 처방 본품은 자식으로 내리지 않음
      if (item.isPrescription) continue;

      final odId = item.odId.trim();
      if (odId.isEmpty) continue;

      CartItem? bestParent;
      for (final p in items) {
        if (p.ctId == item.ctId) continue;
        if (used.contains(p.ctId)) continue;
        if (p.isSupplyAdd) continue;
        if (p.odId.trim() != odId) continue;
        if (!_csvContains(p.itSupplyItems, item.itId)) continue;
        // 서로 supply에 넣은 경우: 처방 쪽을 부모로
        if (item.isPrescription) continue;
        if (bestParent == null) {
          bestParent = p;
          continue;
        }
        if (p.isPrescription && !bestParent.isPrescription) {
          bestParent = p;
        }
      }
      if (bestParent != null) {
        _attach(bestParent, item);
      }
    }

    // 3) od_id 없는 fallback: supply CSV만
    for (final item in items) {
      if (used.contains(item.ctId)) continue;
      if (item.isSupplyAdd) continue;
      if (item.isPrescription) continue;
      // 주문번호가 있으면 독립적으로 담은 일반상품일 수 있으므로 CSV만으로
      // 처방상품의 추가상품에 흡수하면 안 됩니다.
      if (item.odId.trim().isNotEmpty) continue;

      CartItem? matchedParent;
      for (final p in items) {
        if (p.ctId == item.ctId) continue;
        if (used.contains(p.ctId)) continue;
        if (p.isSupplyAdd) continue;
        if (p.odId.trim().isNotEmpty) continue;
        if (!_csvContains(p.itSupplyItems, item.itId)) continue;
        if (matchedParent == null ||
            (p.isPrescription && !matchedParent.isPrescription)) {
          matchedParent = p;
        }
      }
      if (matchedParent != null) {
        _attach(matchedParent, item);
      }
    }

    final groups = <CartLineGroup>[];
    for (final item in items) {
      if (used.contains(item.ctId)) continue;
      if (item.isSupplyAdd) {
        groups.add(CartLineGroup(parent: item));
        used.add(item.ctId);
        continue;
      }
      final kids = childrenByParentCtId[item.ctId] ?? const <CartItem>[];
      for (final c in kids) {
        used.add(c.ctId);
      }
      groups.add(
        CartLineGroup(parent: item, children: List.unmodifiable(kids)),
      );
      used.add(item.ctId);
    }

    return groups;
  }
}
