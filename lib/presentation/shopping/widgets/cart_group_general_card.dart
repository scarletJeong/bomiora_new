import 'package:flutter/material.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'cart_add_group_card.dart';
import 'get_cartImage.dart';

const _kGmarketSans = 'Gmarket Sans TTF';
const _kInk = Color(0xFF1A1A1A);
const _kMuted = Color(0xFF898686);
const _kMuted2 = Color(0xFF898383);
const _kBorder = Color(0x7FD2D2D2);

Widget _cartGrayLine() {
  return const SizedBox(
    width: double.infinity,
    height: 1,
    child: ColoredBox(color: _kBorder),
  );
}

/// 장바구니 업체(브랜드) 표시명 — `it_subject` 우선
String cartVendorName(CartItem item) {
  final subject = item.itSubject?.trim() ?? '';
  if (subject.isNotEmpty) return subject;
  final type = item.productType?.trim() ?? '';
  if (type.isNotEmpty) return type;
  final inf = item.ctMbInf.trim();
  if (inf.isNotEmpty) return inf;
  return '';
}

/// 일반상품 장바구니 — 업체별 묶음배송 카드
///
/// [readOnly]=true 이면 결제/주문완료용 (체크·수량·삭제 숨김).
class CartGroupGeneralCard extends StatelessWidget {
  final String vendorName;
  final List<CartLineGroup> groups;
  final Set<int> selectedItems;
  final bool readOnly;
  final bool showBundleTotal;

  /// true면 추가상품을 본품 아래 '추가상품 N개 포함' 블록으로 보여 준다.
  final bool nestSupplyAdds;
  final Widget Function({
    required bool value,
    required ValueChanged<bool?>? onChanged,
  })? buildCheckbox;
  final Widget Function({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  })? buildQtyControl;
  final void Function(CartItem item, bool selected)? onToggleItem;
  final ValueChanged<bool>? onToggleVendor;
  final void Function(CartItem item, int quantity)? onQuantityChanged;
  final void Function(CartItem item)? onDelete;
  final void Function(CartItem item)? onOpenDetail;

  const CartGroupGeneralCard({
    super.key,
    required this.vendorName,
    required this.groups,
    this.selectedItems = const {},
    this.readOnly = false,
    this.showBundleTotal = true,
    this.nestSupplyAdds = false,
    this.buildCheckbox,
    this.buildQtyControl,
    this.onToggleItem,
    this.onToggleVendor,
    this.onQuantityChanged,
    this.onDelete,
    this.onOpenDetail,
  });

  List<CartItem> get _items =>
      groups.expand((g) => g.allItems).toList(growable: false);

  int get _subtotal =>
      _items.fold<int>(0, (sum, item) => sum + item.lineAmount);

  bool get _allSelected {
    final ids = _items.where((e) => e.isAvailable).map((e) => e.ctId).toSet();
    return ids.isNotEmpty && ids.difference(selectedItems).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    final pad = healthDp(context, 14);

    final productCards = nestSupplyAdds
        ? <Widget>[
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) ...[
                SizedBox(height: healthDp(context, 10)),
                if (!readOnly) ...[
                  _cartGrayLine(),
                  SizedBox(height: healthDp(context, 10)),
                ],
              ],
              _VendorProductCard(
                item: groups[i].parent,
                selected: selectedItems.contains(groups[i].parent.ctId),
                readOnly: readOnly,
                buildCheckbox: buildCheckbox,
                buildQtyControl: buildQtyControl,
                onToggle: (v) => onToggleItem?.call(groups[i].parent, v),
                onQuantityChanged: (q) =>
                    onQuantityChanged?.call(groups[i].parent, q),
                onDelete: () => onDelete?.call(groups[i].parent),
                onOpenDetail: () => onOpenDetail?.call(groups[i].parent),
              ),
              if (groups[i].children.isNotEmpty) ...[
                SizedBox(height: healthDp(context, 10)),
                CartSupplyAddSection(
                  items: groups[i].children,
                  expandWhenSelected:
                      selectedItems.contains(groups[i].parent.ctId),
                  interactive: !readOnly,
                  onQuantityChanged: readOnly ? null : onQuantityChanged,
                  onDelete: readOnly ? null : onDelete,
                  onOpenDetail: onOpenDetail,
                ),
              ],
            ],
          ]
        : <Widget>[
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) ...[
                SizedBox(height: healthDp(context, 10)),
                if (!readOnly) ...[
                  _cartGrayLine(),
                  SizedBox(height: healthDp(context, 10)),
                ],
              ],
              _VendorProductCard(
                item: items[i],
                selected: selectedItems.contains(items[i].ctId),
                readOnly: readOnly,
                buildCheckbox: buildCheckbox,
                buildQtyControl: buildQtyControl,
                onToggle: (v) => onToggleItem?.call(items[i], v),
                onQuantityChanged: (q) => onQuantityChanged?.call(items[i], q),
                onDelete: () => onDelete?.call(items[i]),
                onOpenDetail: () => onOpenDetail?.call(items[i]),
              ),
            ],
          ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!readOnly && buildCheckbox != null) ...[
                buildCheckbox!(
                  value: _allSelected,
                  onChanged: (v) => onToggleVendor?.call(v ?? false),
                ),
                SizedBox(width: healthDp(context, 5)),
              ],
              Flexible(
                child: Text(
                  vendorName.isEmpty ? '판매자' : vendorName,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 14),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showBundleTotal && items.length >= 2) ...[
                SizedBox(width: healthDp(context, 5)),
                Container(
                  padding: EdgeInsets.all(healthDp(context, 5)),
                  decoration: ShapeDecoration(
                    color: const Color(0x0CFF5A8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 50)),
                    ),
                  ),
                  child: Text(
                    '묶음배송',
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 10),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: healthDp(context, 10)),
          _cartGrayLine(),
          SizedBox(height: healthDp(context, 10)),
          ...productCards,
          if (showBundleTotal && items.length >= 2) ...[
            SizedBox(height: healthDp(context, 10)),
            _cartGrayLine(),
            SizedBox(height: healthDp(context, 10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '묶음 합계',
                  style: TextStyle(
                    color: _kMuted2,
                    fontSize: healthSp(context, 12),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -1.08),
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Text(
                  '${PriceFormatter.format(_subtotal)}원',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 16),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VendorProductCard extends StatelessWidget {
  final CartItem item;
  final bool selected;
  final bool readOnly;
  final Widget Function({
    required bool value,
    required ValueChanged<bool?>? onChanged,
  })? buildCheckbox;
  final Widget Function({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  })? buildQtyControl;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetail;

  const _VendorProductCard({
    required this.item,
    required this.selected,
    required this.readOnly,
    required this.buildCheckbox,
    required this.buildQtyControl,
    required this.onToggle,
    required this.onQuantityChanged,
    required this.onDelete,
    required this.onOpenDetail,
  });

  String get _subjectLabel => item.itSubject?.trim() ?? '';

  String get _optionText => item.displayOptionText;

  Widget _soldOutCheckbox(BuildContext context) {
    final size = healthDp(context, 20);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _soldOutThumb(BuildContext context, Widget thumb) {
    if (item.isAvailable) return thumb;
    return Stack(
      alignment: Alignment.center,
      children: [
        thumb,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Text(
          item.unavailableReason ?? '품절',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: healthSp(context, 14),
            fontFamily: _kGmarketSans,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String get _qtyOptionLine {
    final optionParts = _optionText
        .split(RegExp(r'\s*/\s*|\s*ㅣ\s*|\s*\|\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (optionParts.isEmpty) return '수량: ${item.ctQty}';
    return '수량: ${item.ctQty} / ${optionParts.join(' / ')}';
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subjectLabel;
    final option = _optionText;
    final interactive = !readOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interactive)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!item.isAvailable)
                _soldOutCheckbox(context)
              else if (buildCheckbox != null)
                buildCheckbox!(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                )
              else
                const SizedBox.shrink(),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: SizedBox(
                  width: healthDp(context, 20),
                  height: healthDp(context, 20),
                  child: Icon(
                    Icons.close,
                    size: healthDp(context, 16),
                    color: _kBorder,
                  ),
                ),
              ),
            ],
          ),
        if (interactive)
          SizedBox(height: healthDp(context, item.isAvailable ? 10 : 12)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: interactive ? onOpenDetail : null,
              child: _soldOutThumb(
                context,
                CartItemThumbnail(
                  item: item,
                  size: healthDp(context, 64),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subject.isNotEmpty)
                    Text(
                      subject,
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 10),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (subject.isNotEmpty) SizedBox(height: healthDp(context, 2)),
                  GestureDetector(  // 상품명 
                    onTap: interactive ? onOpenDetail : null,
                    child: Text(
                      item.itName,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 14),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -1.26),
                        height: 1.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (readOnly) ...[
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      _qtyOptionLine,
                      style: TextStyle(
                        color: _kMuted2,
                        fontSize: healthSp(context, 12),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -1.08),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      '${PriceFormatter.format(item.lineAmount)}원',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 16),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (option.isNotEmpty) ...[
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      option,
                      style: TextStyle(
                        color: _kMuted2,
                        fontSize: healthSp(context, 12),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -1.08),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (interactive && buildQtyControl != null) ...[
          SizedBox(height: healthDp(context, item.isAvailable ? 10 : 20)),
          Container(
            width: double.infinity,
            decoration: item.isAvailable
                ? null
                : const BoxDecoration(
                    border: Border(
                      top: BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
                    ),
                  ),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IgnorePointer(
                ignoring: !item.isAvailable,
                child: Opacity(
                  opacity: item.isAvailable ? 1 : 0.5,
                  child: buildQtyControl!(
                    quantity: item.ctQty,
                    onDecrease: item.isAvailable && item.ctQty > 1
                        ? () => onQuantityChanged(item.ctQty - 1)
                        : null,
                    onIncrease: () => onQuantityChanged(item.ctQty + 1),
                  ),
                ),
              ),
              Text(
                '${PriceFormatter.format(item.lineAmount)}원',
                style: TextStyle(
                  color: _kInk,
                  fontSize: healthSp(context, 16),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          ),
        ],
      ],
    );
  }
}

/// 일반상품 라인 그룹을 업체명 기준으로 묶습니다.
List<MapEntry<String, List<CartLineGroup>>> groupCartByVendor(
  List<CartLineGroup> groups,
) {
  final map = <String, List<CartLineGroup>>{};
  for (final group in groups) {
    final name = cartVendorName(group.parent);
    map.putIfAbsent(name, () => []).add(group);
  }
  return map.entries.toList(growable: false);
}
