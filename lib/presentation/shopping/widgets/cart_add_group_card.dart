import 'package:flutter/material.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'get_cartImage.dart';

const _kGmarketSans = 'Gmarket Sans TTF';
const _kPink = Color(0xFFFF5A8D);
const _kInk = Color(0xFF1A1A1A);
const _kInkAlt = Color(0xFF1A1A1E);
const _kMuted = Color(0xFF898686);
const _kMuted2 = Color(0xFF898383);
const _kBorder = Color(0x7FD2D2D2);
const _kBorderSoft = Color(0x33FF5A8D);
const _kDivider = Color(0x26FF5A8D);
const _kHeaderBg = Colors.white;
const _kRowBg = Colors.white;

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
  final bool showSameReservationHint;

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
    this.showSameReservationHint = true,
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
              showSameReservationHint: showSameReservationHint,
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
    if (g.parent.isSupplyAdd) return false;
    final parentIsRx = g.parent.isPrescription;
    return prescriptionTab ? parentIsRx : !parentIsRx;
  }).toList();
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

/// 추가상품(supply_add) 리스트 UI — [CartAddGroupCard] 내부용
class _SupplyAddBlock extends StatelessWidget {
  const _SupplyAddBlock({
    required this.items,
    this.onQuantityChanged,
    this.onDelete,
    this.onOpenDetail,
    this.interactive = true,
    this.showSameReservationHint = true,
  });

  final List<CartItem> items;
  final void Function(CartItem item, int quantity)? onQuantityChanged;
  final void Function(CartItem item)? onDelete;
  final void Function(CartItem item)? onOpenDetail;
  final bool interactive;
  final bool showSameReservationHint;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final merged = _MergedSupplyLine.merge(items);
    final canEdit = interactive && onQuantityChanged != null;
    final radius = healthDp(context, 8);

    // 테두리와 clip을 분리해 상단 양끝 라운드 보더가 가려지지 않게 함
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(width: 1, color: _kBorderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius > 1 ? radius - 1 : radius),
        child: ColoredBox(
          color: _kRowBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, count: merged.length),
              for (var i = 0; i < merged.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: _kDivider),
                _SupplyAddRow(
                  line: merged[i],
                  canEdit: canEdit,
                  onDecrease: !canEdit
                      ? null
                      : () {
                          final line = merged[i];
                          final primary = line.primary;
                          if (primary.ctQty > 1) {
                            onQuantityChanged!(primary, primary.ctQty - 1);
                          } else if (line.lines.length > 1 &&
                              onDelete != null) {
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
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required int count}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 7),
      ),
      decoration: const BoxDecoration(
        color: _kHeaderBg,
        border: Border(
          bottom: BorderSide(width: 1, color: _kDivider),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: healthDp(context, 6),
            height: healthDp(context, 6),
            decoration: const BoxDecoration(
              color: _kPink,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: healthDp(context, 6)),
          Text(
            '추가 상품 $count개',
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, 10),
              fontFamily: _kGmarketSans,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          SizedBox(width: healthDp(context, 6)),
          Expanded(
            child: Container(
              height: 0.5,
              color: _kBorderSoft,
            ),
          ),
          if (showSameReservationHint) ...[
            SizedBox(width: healthDp(context, 6)),
            Icon(
              Icons.schedule,
              size: healthSp(context, 10),
              color: _kMuted,
            ),
            SizedBox(width: healthDp(context, 3)),
            Text(
              '동일 예약',
              style: TextStyle(
                color: _kMuted,
                fontSize: healthSp(context, 9),
                fontFamily: _kGmarketSans,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(context, Icons.remove, onDecrease, filled: true),
        SizedBox(width: healthDp(context, 6)),
        Text(
          '$quantity',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kInk,
            fontSize: healthSp(context, 11),
            fontFamily: 'Arimo',
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        SizedBox(width: healthDp(context, 6)),
        _btn(context, Icons.add, onIncrease, filled: false),
      ],
    );
  }

  Widget _btn(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap, {
    required bool filled,
  }) {
    final size = healthDp(context, 20);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: filled ? const Color(0xFFF9F9F9) : Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(
              width: 1,
              color: _kBorder,
            ),
            borderRadius: BorderRadius.circular(size),
          ),
        ),
        child: Icon(
          icon,
          size: healthSp(context, 10),
          color: onTap == null ? Colors.grey[300] : _kInk,
        ),
      ),
    );
  }
}
