import 'package:flutter/material.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'get_cartImage.dart';
import 'quantity_stepper.dart';
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

  /// 결제·주문 상세처럼 체크가 없을 때 추가상품을 펼친 채로 둔다.
  final bool supplyInitiallyExpanded;

  /// 비대면 장바구니 카드. 추가상품 헤더 금액과 본품+추가상품 합계를 쓴다.
  final bool prescriptionCartLayout;

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
    this.supplyInitiallyExpanded = false,
    this.prescriptionCartLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = group.children;
    if (children.isEmpty) {
      return buildParentOrMainCard(group.parent, isChild: false);
    }

    final pad = healthDp(context, 10);
    final cartLayout = prescriptionCartLayout;
    final addAmount =
        children.fold<int>(0, (sum, item) => sum + item.lineAmount);

    return buildParentOrMainCard(
      group.parent,
      isChild: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: healthDp(context, cartLayout ? 16 : 12)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: cartLayout ? 0 : pad,
            ),
            child: _SupplyAddBlock(
              items: children,
              expandWhenSelected: selectedItems.contains(group.parent.ctId),
              initiallyExpanded: supplyInitiallyExpanded,
              interactive: supplyInteractive,
              prescriptionCartLayout: cartLayout,
              amountLabel: cartLayout
                  ? '+${PriceFormatter.format(addAmount)}원'
                  : null,
              onQuantityChanged: onChildQuantityChanged,
              onDelete: onChildDelete,
              onOpenDetail: onChildOpenDetail,
            ),
          ),
          if (showBundleTotal) ...[
            SizedBox(height: healthDp(context, cartLayout ? 14 : 12)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cartLayout ? 0 : pad,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    cartLayout ? '본품+추가상품 합계' : '묶음 합계',
                    style: TextStyle(
                      color: _kMuted2,
                      fontSize: healthSp(context, cartLayout ? 12 : 10),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                      height: cartLayout ? null : 1.5,
                      letterSpacing: healthSp(
                        context,
                        cartLayout ? -1.08 : -0.90,
                      ),
                    ),
                  ),
                  SizedBox(width: healthDp(context, 10)),
                  Text(
                    '${PriceFormatter.format(group.groupAmount)}원',
                    style: TextStyle(
                      color: _kInkAlt,
                      fontSize: healthSp(context, cartLayout ? 16 : 14),
                      fontFamily: _kGmarketSans,
                      fontWeight:
                          cartLayout ? FontWeight.w700 : FontWeight.w500,
                      height: cartLayout ? null : 1.5,
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

/// 추가상품(supply_add) 펼침 블록. 처방·일반 장바구니가 같은 UI를 쓴다.
class CartSupplyAddSection extends StatelessWidget {
  const CartSupplyAddSection({
    super.key,
    required this.items,
    this.onQuantityChanged,
    this.onDelete,
    this.onOpenDetail,
    this.interactive = true,
    this.expandWhenSelected = false,
    this.initiallyExpanded = false,
  });

  final List<CartItem> items;
  final void Function(CartItem item, int quantity)? onQuantityChanged;
  final void Function(CartItem item)? onDelete;
  final void Function(CartItem item)? onOpenDetail;
  final bool interactive;
  final bool expandWhenSelected;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return _SupplyAddBlock(
      items: items,
      onQuantityChanged: onQuantityChanged,
      onDelete: onDelete,
      onOpenDetail: onOpenDetail,
      interactive: interactive,
      expandWhenSelected: expandWhenSelected,
      initiallyExpanded: initiallyExpanded,
    );
  }
}

/// 추가상품(supply_add) 리스트 UI — [CartAddGroupCard] 내부용
class _SupplyAddBlock extends StatelessWidget {
  const _SupplyAddBlock({
    required this.items,
    this.onQuantityChanged,
    this.onDelete,
    this.onOpenDetail,
    this.interactive = true,
    this.expandWhenSelected = false,
    this.initiallyExpanded = false,
    this.prescriptionCartLayout = false,
    this.amountLabel,
  });

  final List<CartItem> items;
  final void Function(CartItem item, int quantity)? onQuantityChanged;
  final void Function(CartItem item)? onDelete;
  final void Function(CartItem item)? onOpenDetail;
  final bool interactive;
  final bool expandWhenSelected;
  final bool initiallyExpanded;
  final bool prescriptionCartLayout;
  final String? amountLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final merged = _MergedSupplyLine.merge(items);
    final canEdit = interactive && onQuantityChanged != null;

    return SupplyAddExpandBlock(
      count: merged.length,
      expandWhenSelected: expandWhenSelected,
      initiallyExpanded: initiallyExpanded,
      showSameReservationHint: false,
      amountLabel: prescriptionCartLayout ? amountLabel : null,
      headerPadding: prescriptionCartLayout
          ? EdgeInsets.all(healthDp(context, 12))
          : null,
      iconGapBase: prescriptionCartLayout ? 4 : 6,
      chevronBase: prescriptionCartLayout ? 11 : 16,
      children: [
        for (var i = 0; i < merged.length; i++) ...[
          if (i > 0 && !prescriptionCartLayout)
            const Divider(height: 1, thickness: 1, color: _kDivider),
          _SupplyAddRow(
            line: merged[i],
            canEdit: canEdit,
            prescriptionCartLayout: prescriptionCartLayout,
            showBottomBorder:
                prescriptionCartLayout && i < merged.length - 1,
            onDecrease: !canEdit
                ? null
                : () {
                    final line = merged[i];
                    final primary = line.primary;
                    if (primary.ctQty > 1) {
                      onQuantityChanged!(primary, primary.ctQty - 1);
                    } else if (line.lines.length > 1 && onDelete != null) {
                      onDelete!(primary);
                    }
                  },
            onIncrease: canEdit
                ? () {
                    final primary = merged[i].primary;
                    onQuantityChanged!(primary, primary.ctQty + 1);
                  }
                : null,
            onDelete: interactive && onDelete != null
                ? () {
                    for (final item in merged[i].lines) {
                      onDelete!(item);
                    }
                  }
                : null,
            onOpenDetail: onOpenDetail == null
                ? null
                : () => onOpenDetail!(merged[i].primary),
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
    this.prescriptionCartLayout = false,
    this.showBottomBorder = false,
  });

  final _MergedSupplyLine line;
  final bool canEdit;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenDetail;
  final bool prescriptionCartLayout;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final item = line.primary;
    final rawOption = item.displayOptionText;
    final option = prescriptionCartLayout
        ? rawOption.replaceAll(']_', '] ').trim()
        : rawOption;
    final thumb = healthDp(context, 44);
    final canDecrease = canEdit &&
        line.totalQty > 1 &&
        (line.primary.ctQty > 1 || line.lines.length > 1);
    final cart = prescriptionCartLayout;

    if (cart) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(healthDp(context, 12)),
        decoration: showBottomBorder
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: healthDp(context, 1.11),
                    color: const Color(0x1EFF5A8D),
                  ),
                ),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onOpenDetail,
              child: CartItemThumbnail(
                item: item,
                size: thumb,
                borderRadius: BorderRadius.circular(healthDp(context, 6)),
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.itName,
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 12),
                            fontFamily: _kGmarketSans,
                            fontWeight: FontWeight.w500,
                            letterSpacing: healthSp(context, -1.08),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onDelete != null)
                        InkWell(
                          onTap: onDelete,
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 8)),
                          child: SizedBox(
                            width: healthDp(context, 16),
                            height: healthDp(context, 16),
                            child: Icon(
                              Icons.close,
                              size: healthDp(context, 14),
                              color: const Color(0xFF898686),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (option.isNotEmpty) ...[
                    SizedBox(height: healthDp(context, 2)),
                    Text(
                      option,
                      style: TextStyle(
                        color: _kMuted2,
                        fontSize: healthSp(context, 10),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -0.60),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: healthDp(context, 8)),
                  Row(
                    children: [
                      if (canEdit)
                        QuantityStepper(
                          quantity: line.totalQty,
                          onDecrease: canDecrease ? onDecrease : null,
                          onIncrease: onIncrease,
                          buttonBase: 24,
                          paddingBase: 2,
                          gapBase: 0,
                          numberWidthBase: 24,
                        )
                      else
                        Text(
                          '수량: ${line.totalQty}',
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 12),
                            fontFamily: _kGmarketSans,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '+${PriceFormatter.format(line.totalAmount)}원',
                        style: TextStyle(
                          color: _kInkAlt,
                          fontSize: healthSp(context, 12),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
                      QuantityStepper(
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

