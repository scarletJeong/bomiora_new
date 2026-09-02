import 'package:flutter/material.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'get_cartImage.dart';

const _kGmarketSans = 'Gmarket Sans TTF';
const _kInk = Color(0xFF1A1A1A);
const _kMuted = Color(0xFF898686);
const _kMuted2 = Color(0xFF898383);
const _kBorder = Color(0x7FD2D2D2);

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

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) ...[
                    SizedBox(height: healthDp(context, 10)),
                    Container(
                      width: double.infinity,
                      height: 0.5,
                      color: _kBorder,
                    ),
                    SizedBox(height: healthDp(context, 10)),
                  ],
                  _VendorProductCard(
                    item: items[i],
                    selected: selectedItems.contains(items[i].ctId),
                    readOnly: readOnly,
                    compactBottom: items.length < 2,
                    buildCheckbox: buildCheckbox,
                    buildQtyControl: buildQtyControl,
                    onToggle: (v) => onToggleItem?.call(items[i], v),
                    onQuantityChanged: (q) =>
                        onQuantityChanged?.call(items[i], q),
                    onDelete: () => onDelete?.call(items[i]),
                    onOpenDetail: () => onOpenDetail?.call(items[i]),
                  ),
                ],
                if (items.length >= 2)
                  SizedBox(height: healthDp(context, 7)),
              ],
            ),
          ),
          if (showBundleTotal && items.length >= 2) ...[
            // 묶음 합계 위 회색선 — 카드 테두리에서 살짝 띄움
            Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              child: Container(
                width: double.infinity,
                height: 0.5,
                color: _kBorder,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, healthDp(context, 14), pad, pad),
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
                      letterSpacing: -0.90,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 10)),
                  Text(
                    '${PriceFormatter.format(_subtotal)}원',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 14),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: healthDp(context, items.length < 2 ? 10 : 14)),
        ],
      ),
    );
  }
}

class _VendorProductCard extends StatelessWidget {
  final CartItem item;
  final bool selected;
  final bool readOnly;
  final bool compactBottom;
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
    this.compactBottom = false,
    required this.buildCheckbox,
    required this.buildQtyControl,
    required this.onToggle,
    required this.onQuantityChanged,
    required this.onDelete,
    required this.onOpenDetail,
  });

  String get _subjectLabel => item.itSubject?.trim() ?? '';

  String get _optionText => item.ctOption.trim();

  Widget _soldOutThumb(BuildContext context, Widget thumb) {
    if (item.isAvailable) return thumb;
    return Stack(
      children: [
        Opacity(opacity: 0.4, child: thumb),
        Positioned.fill(
          child: Center(
            child: Text(
              item.unavailableReason ?? '품절',
              style: TextStyle(
                color: Colors.white,
                fontSize: healthSp(context, 10),
                fontFamily: _kGmarketSans,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
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
    return '수량: ${item.ctQty} ㅣ ${optionParts.join(' ㅣ ')}';
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subjectLabel;
    final option = _optionText;
    final interactive = !readOnly;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 10),
        healthDp(context, readOnly ? 10 : 20),
        healthDp(context, 10),
        healthDp(context, readOnly ? 10 : (compactBottom ? 4 : 20)),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (interactive && buildCheckbox != null) ...[
            buildCheckbox!(
              value: selected,
              onChanged: item.isAvailable
                  ? (v) => onToggle(v ?? false)
                  : null,
            ),
            SizedBox(width: healthDp(context, 5)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: interactive ? onOpenDetail : null,
                            child: _soldOutThumb(
                              context,
                              CartItemThumbnail(
                                item: item,
                                size: healthDp(context, readOnly ? 72 : 60),
                              ),
                            ),
                          ),
                          SizedBox(width: healthDp(context, readOnly ? 20 : 8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!readOnly && subject.isNotEmpty) ...[
                                  Text(
                                    subject,
                                    style: TextStyle(
                                      color: _kMuted,
                                      fontSize: healthSp(context, 8),
                                      fontFamily: _kGmarketSans,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: healthDp(context, 2)),
                                ],
                                GestureDetector(
                                  onTap: interactive ? onOpenDetail : null,
                                  child: Text(
                                    item.itName,
                                    style: TextStyle(
                                      color: item.isAvailable ? _kInk : _kMuted,
                                      fontSize: healthSp(context, 14),
                                      fontFamily: _kGmarketSans,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -1.26,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!item.isAvailable) ...[
                                  SizedBox(height: healthDp(context, 4)),
                                  Text(
                                    item.unavailableReason ?? '품절',
                                    style: TextStyle(
                                      color: const Color(0xFFFF5A8D),
                                      fontSize: healthSp(context, 11),
                                      fontFamily: _kGmarketSans,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                if (readOnly) ...[
                                  SizedBox(height: healthDp(context, 5)),
                                  Text(
                                    _qtyOptionLine,
                                    style: TextStyle(
                                      color: _kMuted2,
                                      fontSize: healthSp(context, 10),
                                      fontFamily: _kGmarketSans,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.40,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: healthDp(context, 5)),
                                  Text(
                                    '${PriceFormatter.format(item.lineAmount)}원',
                                    style: TextStyle(
                                      color: _kInk,
                                      fontSize: healthSp(context, 14),
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
                                      fontSize: healthSp(context, 10),
                                      fontFamily: _kGmarketSans,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.90,
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
                    ),
                    if (interactive)
                      InkWell(
                        onTap: onDelete,
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
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
                if (interactive && buildQtyControl != null) ...[
                  SizedBox(height: healthDp(context, 20)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      buildQtyControl!(
                        quantity: item.ctQty,
                        onDecrease: item.ctQty > 1
                            ? () => onQuantityChanged(item.ctQty - 1)
                            : null,
                        onIncrease: () => onQuantityChanged(item.ctQty + 1),
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
                ],
              ],
            ),
          ),
        ],
      ),
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
