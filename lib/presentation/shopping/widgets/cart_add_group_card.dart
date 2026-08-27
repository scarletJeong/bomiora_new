import 'package:flutter/material.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'get_cartImage.dart';
import 'supply_add_expand_block.dart';

const _kGmarketSans = 'Gmarket Sans TTF';
const _kInk = Color(0xFF1A1A1A);
const _kInkAlt = Color(0xFF1A1A1E);
const _kMuted2 = Color(0xFF898383);
const _kBorder = Color(0x7FD2D2D2);
const _kDivider = Color(0x26FF5A8D);

/// 처방 장바구니 — 본상품 + 추가상품(supply_add) 묶음 카드
class CartAddGroupCard extends StatelessWidget {
  final CartLineGroup group;
  final Set<int> selectedItems;
  final Widget Function(
    CartItem item, {
    required bool isChild,
    Widget? footer,
  }) buildParentOrMainCard;
  final void Function(CartItem item, bool selected) onToggleSelect;
  final VoidCallback? onDeleteParent;
  final void Function(CartItem item, int quantity)? onChildQuantityChanged;
  final void Function(CartItem item)? onChildDelete;
  final void Function(CartItem item)? onChildOpenDetail;
  final bool showBundleTotal;
  final bool supplyInteractive;

  const CartAddGroupCard({
    super.key,
    required this.group,
    required this.selectedItems,
    required this.buildParentOrMainCard,
    required this.onToggleSelect,
    this.onDeleteParent,
    this.onChildQuantityChanged,
    this.onChildDelete,
    this.onChildOpenDetail,
    this.showBundleTotal = true,
    this.supplyInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = group.children;
    if (children.isEmpty) {
      return buildParentOrMainCard(group.parent, isChild: false);
    }

    final pad = healthDp(context, 10);

    return buildParentOrMainCard(
      group.parent,
      isChild: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: healthDp(context, 12)),
          // 수량 버튼 왼쪽과 동일 정렬 (카드 내부 +10)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: _SupplyAddBlock(
              items: children,
              interactive: supplyInteractive,
              onQuantityChanged: onChildQuantityChanged,
              onDelete: onChildDelete,
              onOpenDetail: onChildOpenDetail,
            ),
          ),
          if (showBundleTotal) ...[
            // 수량 아래 회색선 없이 합계만 (추가상품 박스와 동일 폭)
            SizedBox(height: healthDp(context, 12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '묶음 합계',
                    style: TextStyle(
                      color: _kMuted2,
                      fontSize: healthSp(context, 10),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: -0.90,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 10)),
                  Text(
                    '${PriceFormatter.format(group.groupAmount)}원',
                    style: TextStyle(
                      color: _kInkAlt,
                      fontSize: healthSp(context, 14),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 탭(처방/일반)에 맞는 장바구니 라인 그룹
///
/// 추가상품(supply_add / 같은 od_id 묶음)은 부모 카드의 children으로만 노출합니다.
List<CartLineGroup> cartGroupsForTab(
  List<CartItem> allItems, {
  required bool prescriptionTab,
}) {
  final groups = CartLineGroup.groupItems(allItems);
  return groups.where((g) {
    final parent = g.parent;
    if (parent.isSupplyAdd) {
      if (prescriptionTab) return parent.isPrescription;
      return _isGeneralCartLine(parent);
    }
    final parentIsRx = parent.isPrescription;
    return prescriptionTab ? parentIsRx : !parentIsRx;
  }).toList();
}

bool _isGeneralCartLine(CartItem item) {
  final ck = item.ctKind.trim().toLowerCase();
  if (ck == 'general') return true;
  if (ck == 'prescription') return false;
  return !item.isPrescription;
}

/// 동일 상품·옵션 라인을 수량으로 합친 표시용
class _MergedSupplyLine {
  const _MergedSupplyLine(this.lines);

  final List<CartItem> lines;

  CartItem get primary => lines.first;

  int get totalQty => lines.fold<int>(0, (s, e) => s + e.ctQty);

  int get totalAmount => lines.fold<int>(0, (s, e) => s + e.lineAmount);

  static String keyOf(CartItem item) {
    final io = item.ioId?.trim() ?? '';
    return '${item.itId.trim()}|${item.ctOption.trim()}|$io|${item.ioType}';
  }

  static List<_MergedSupplyLine> merge(List<CartItem> items) {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(keyOf(item), () => []).add(item);
    }
    return map.values
        .map((list) => _MergedSupplyLine(List.unmodifiable(list)))
        .toList(growable: false);
  }
}

/// 추가상품(supply_add) 리스트 UI — [CartAddGroupCard] 내부용 (기본 접힘)
class _SupplyAddBlock extends StatefulWidget {
  const _SupplyAddBlock({
    required this.items,
    this.onQuantityChanged,
    this.onDelete,
    this.onOpenDetail,
    this.interactive = true,
  });

  final List<CartItem> items;
  final void Function(CartItem item, int quantity)? onQuantityChanged;
  final void Function(CartItem item)? onDelete;
  final void Function(CartItem item)? onOpenDetail;
  final bool interactive;

  @override
  State<_SupplyAddBlock> createState() => _SupplyAddBlockState();
}

class _SupplyAddBlockState extends State<_SupplyAddBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final merged = _MergedSupplyLine.merge(widget.items);
    final canEdit = widget.interactive && widget.onQuantityChanged != null;

    return SupplyAddExpandBlock(
      count: merged.length,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      showSameReservationHint: false,
      children: [
        for (var i = 0; i < merged.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: _kDivider),
          _SupplyAddRow(
            line: merged[i],
            canEdit: canEdit,
            onDecrease: !canEdit
                ? null
                : () {
                    final line = merged[i];
                    final primary = line.primary;
                    if (primary.ctQty > 1) {
                      widget.onQuantityChanged!(primary, primary.ctQty - 1);
                    } else if (line.lines.length > 1 &&
                        widget.onDelete != null) {
                      widget.onDelete!(primary);
                    }
                  },
            onIncrease: canEdit
                ? () {
                    final primary = merged[i].primary;
                    widget.onQuantityChanged!(primary, primary.ctQty + 1);
                  }
                : null,
            onDelete: widget.interactive && widget.onDelete != null
                ? () {
                    for (final item in merged[i].lines) {
                      widget.onDelete!(item);
                    }
                  }
                : null,
            onOpenDetail: widget.onOpenDetail == null
                ? null
                : () => widget.onOpenDetail!(merged[i].primary),
          ),
        ],
      ],
    );
  }
}

class _SupplyAddRow extends StatelessWidget {
  const _SupplyAddRow({
    required this.line,
    required this.canEdit,
    this.onDecrease,
    this.onIncrease,
    this.onDelete,
    this.onOpenDetail,
  });

  final _MergedSupplyLine line;
  final bool canEdit;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final item = line.primary;
    final option = item.ctOption.trim();
    final thumb = healthDp(context, 44);
    final canDecrease = canEdit &&
        line.totalQty > 1 &&
        (line.primary.ctQty > 1 || line.lines.length > 1);

    return Padding(
      padding: EdgeInsets.all(healthDp(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onOpenDetail,
            child: CartItemThumbnail(
              item: item,
              size: thumb,
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
            ),
          ),
          SizedBox(width: healthDp(context, 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.itName,
                  style: TextStyle(
                    color: _kInkAlt,
                    fontSize: healthSp(context, 12),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    letterSpacing: -0.84,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (option.isNotEmpty) ...[
                  SizedBox(height: healthDp(context, 4)),
                  Text(
                    option,
                    style: TextStyle(
                      color: _kMuted2,
                      fontSize: healthSp(context, 9),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                      height: 1.63,
                      letterSpacing: -0.45,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: healthDp(context, 4)),
                Row(
                  children: [
                    if (canEdit)
                      _MiniQtyControl(
                        quantity: line.totalQty,
                        onDecrease: canDecrease ? onDecrease : null,
                        onIncrease: onIncrease,
                      )
                    else
                      Text(
                        '수량: ${line.totalQty}',
                        style: TextStyle(
                          color: _kInk,
                          fontSize: healthSp(context, 11),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '+${PriceFormatter.format(line.totalAmount)}원',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 10),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        height: 1.95,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
            SizedBox(width: healthDp(context, 4)),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 2)),
                child: Icon(
                  Icons.close,
                  size: healthSp(context, 14),
                  color: _kBorder,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniQtyControl extends StatelessWidget {
  const _MiniQtyControl({
    required this.quantity,
    this.onDecrease,
    this.onIncrease,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circleBtn(context, Icons.remove, onDecrease),
          SizedBox(
            width: healthDp(context, 18),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 12),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                height: 0.79,
              ),
            ),
          ),
          _circleBtn(context, Icons.add, onIncrease),
        ],
      ),
    );
  }

  Widget _circleBtn(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Container(
        width: healthDp(context, 20),
        height: healthDp(context, 20),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x0C000000),
              blurRadius: healthDp(context, 1.07),
              offset: Offset(0, healthDp(context, 0.54)),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: healthDp(context, 14),
          color: onTap == null ? Colors.grey[300] : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}
