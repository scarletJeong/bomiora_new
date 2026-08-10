import 'package:flutter/material.dart';

import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../data/models/delivery/delivery_model.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../review/review_write_general_screen.dart';
import '../../review/review_write_screen.dart';

/// 리뷰 작성 대상 본품만 (추가상품 제외)
List<OrderItem> reviewableOrderProducts(OrderDetailModel order) {
  return order.products.where((p) {
    if (p.itId.trim().isEmpty) return false;
    final parent = (p.parent ?? '').trim();
    if (parent.isNotEmpty) return false;
    final kind = (p.ctKind ?? '').toLowerCase().trim();
    if (kind.startsWith('supply_add|')) return false;
    return true;
  }).toList();
}

/// 아직 리뷰 미작성인 본품만
List<OrderItem> pendingReviewProducts(
  OrderDetailModel order,
  Iterable<String> reviewedItIds,
) {
  final reviewed = reviewedItIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  return reviewableOrderProducts(order)
      .where((p) => !reviewed.contains(p.itId.trim()))
      .toList();
}

/// 주문 상품 선택 후 리뷰쓰기 (복수 상품일 때)
class DeliverySelectList extends StatefulWidget {
  const DeliverySelectList({
    super.key,
    required this.orderDetail,
    this.pendingProducts,
  });

  final OrderDetailModel orderDetail;
  /// 미리 필터된 미작성 상품 (없으면 orderDetail 전체 본품)
  final List<OrderItem>? pendingProducts;

  @override
  State<DeliverySelectList> createState() => _DeliverySelectListState();
}

class _DeliverySelectListState extends State<DeliverySelectList> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const String _kFont = 'Gmarket Sans TTF';

  late final List<OrderItem> _products;
  final Set<int> _selectedCtIds = {};

  @override
  void initState() {
    super.initState();
    _products = widget.pendingProducts ??
        reviewableOrderProducts(widget.orderDetail);
  }

  bool get _allSelected =>
      _products.isNotEmpty && _selectedCtIds.length == _products.length;

  bool get _hasSelection => _selectedCtIds.isNotEmpty;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedCtIds.clear();
      } else {
        _selectedCtIds
          ..clear()
          ..addAll(_products.map((e) => e.ctId));
      }
    });
  }

  void _toggleOne(OrderItem item) {
    setState(() {
      if (_selectedCtIds.contains(item.ctId)) {
        _selectedCtIds.remove(item.ctId);
      } else {
        _selectedCtIds.add(item.ctId);
      }
    });
  }

  Future<void> _onConfirm() async {
    if (!_hasSelection) {
      AppToastOverlay.show(context, '상품을 선택해 주세요');
      return;
    }
    final selected = _products
        .where((p) => _selectedCtIds.contains(p.ctId))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final isRx = widget.orderDetail.isPrescriptionOrder;
    final written = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => isRx
            ? ReviewWriteScreen(
                orderDetail: widget.orderDetail,
                selectedProducts: selected,
              )
            : ReviewWriteGeneralScreen(
                orderDetail: widget.orderDetail,
                selectedProducts: selected,
              ),
      ),
    );
    if (!mounted) return;
    if (written == true) {
      Navigator.pop(context, true);
    }
  }

  String _optionLine(OrderItem item) {
    final option = (item.ctOption ?? '').trim();
    if (option.isEmpty) return '수량: ${item.ctQty}';
    return '수량: ${item.ctQty}ㅣ$option';
  }

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 20);

    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: '리뷰쓰기',
        titleFontSize: healthSp(context, 16),
        leadingIconSize: healthDp(context, 24),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                padH,
                healthDp(context, 10),
                padH,
                healthDp(context, 24),
              ),
              children: [
                Text(
                  '리뷰를 작성할 상품을 선택해 주세요',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 15),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 12),
                      vertical: healthDp(context, 4),
                    ),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFFF0F5),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 999)),
                      ),
                    ),
                    child: Text(
                      '주문번호: ${widget.orderDetail.odId}',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: healthSp(context, 11),
                        fontFamily: _kFont,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: healthDp(context, 20)),
                InkWell(
                  onTap: _toggleAll,
                  child: Row(
                    children: [
                      _checkCircle(selected: _allSelected),
                      SizedBox(width: healthDp(context, 8)),
                      Text(
                        '전체선택',
                        style: TextStyle(
                          color: _kInk,
                          fontSize: healthSp(context, 13),
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: healthDp(context, 16)),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: const Color(0x66D2D2D2),
                ),
                SizedBox(height: healthDp(context, 16)),
                for (var i = 0; i < _products.length; i++) ...[
                  if (i > 0) SizedBox(height: healthDp(context, 16)),
                  _productRow(_products[i]),
                ],
              ],
            ),
          ),
          _bottomBar(context),
        ],
      ),
    );
  }

  Widget _productRow(OrderItem item) {
    final selected = _selectedCtIds.contains(item.ctId);
    final thumb = healthDp(context, 64);
    final url = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
        ? ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId)
        : null;

    return InkWell(
      onTap: () => _toggleOne(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _checkCircle(selected: selected),
          SizedBox(width: healthDp(context, 12)),
          Container(
            width: thumb,
            height: thumb,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: const Color(0xFFF6F6F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 8)),
              ),
            ),
            child: url == null
                ? Icon(Icons.image_outlined, color: _kMuted, size: healthDp(context, 28))
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_outlined,
                      color: _kMuted,
                      size: healthDp(context, 28),
                    ),
                  ),
          ),
          SizedBox(width: healthDp(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 13),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                    height: 1.38,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: healthDp(context, 4)),
                Text(
                  _optionLine(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 11),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: healthDp(context, 4)),
                Text(
                  '${PriceFormatter.format(item.totalPrice)}원',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: healthSp(context, 13),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkCircle({required bool selected}) {
    final size = healthDp(context, 20);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: selected ? _kPink : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1.06,
            color: selected ? _kPink : _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 999)),
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: healthDp(context, 14), color: Colors.white)
          : null,
    );
  }

  Widget _bottomBar(BuildContext context) {
    final enabled = _hasSelection;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 20),
          healthDp(context, 13),
          healthDp(context, 20),
          healthDp(context, 13),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(width: 1, color: const Color(0x7FD2D2D2)),
          ),
        ),
        child: Material(
          color: enabled ? _kPink : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
          child: InkWell(
            onTap: enabled ? _onConfirm : null,
            borderRadius: BorderRadius.circular(healthDp(context, 50)),
            child: SizedBox(
              height: healthDp(context, 49),
              child: Center(
                child: Text(
                  enabled
                      ? '리뷰쓰기 (${_selectedCtIds.length})'
                      : '상품을 선택해 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled ? Colors.white : const Color(0xFFC0B9B9),
                    fontSize: healthSp(context, 14),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
