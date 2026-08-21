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
  final reviewed =
      reviewedItIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
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
  final List<OrderItem>? pendingProducts;

  @override
  State<DeliverySelectList> createState() => _DeliverySelectListState();
}

class _DeliverySelectListState extends State<DeliverySelectList> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kInkDark = Color(0xFF1A1A1A);
  static const Color _kGrey60 = Color(0xFF999999);
  static const Color _kGrey55 = Color(0xFF555555);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kMutedOpt = Color(0xFF898383);
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kLine = Color(0xFFF5F5F5);
  static const String _kFont = 'Gmarket Sans TTF';

  late final List<OrderItem> _products;
  final Set<int> _selectedCtIds = {};

  @override
  void initState() {
    super.initState();
    _products =
        widget.pendingProducts ?? reviewableOrderProducts(widget.orderDetail);
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

  List<String> _metaParts(OrderItem item) {
    final parts = <String>['수량: ${item.ctQty}'];
    final option = (item.ctOption ?? '').trim();
    if (option.isEmpty) return parts;
    if (option.contains(' / ')) {
      parts.addAll(
        option
            .split(' / ')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    } else if (option.contains('|')) {
      parts.addAll(
        option.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    } else {
      parts.add(option);
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
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
              padding: EdgeInsets.zero,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 20),
                    vertical: healthDp(context, 10),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: healthDp(context, 1),
                        color: _kBorder,
                      ),
                    ),
                  ),
                  child: Text(
                    '리뷰를 작성하실 상품을 선택해 주세요.',
                    style: TextStyle(
                      color: _kInkDark,
                      fontSize: healthSp(context, 18),
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w300,
                      height: 1.40,
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: healthDp(context, 14),
                    left: healthDp(context, 20),
                    right: healthDp(context, 20),
                    bottom: healthDp(context, 10),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: healthDp(context, 1),
                        color: _kLine,
                      ),
                    ),
                  ),
                  child: InkWell(
                    onTap: _toggleAll,
                    child: Row(
                      children: [
                        _checkSquare(selected: _allSelected),
                        SizedBox(width: healthDp(context, 8)),
                        Text(
                          '주문번호',
                          style: TextStyle(
                            color: _kGrey60,
                            fontSize: healthSp(context, 12),
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w300,
                            height: 1.50,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 10)),
                        Text(
                          widget.orderDetail.odId,
                          style: TextStyle(
                            color: _kGrey55,
                            fontSize: healthSp(context, 12),
                            fontFamily: _kFont,
                            fontWeight: FontWeight.w300,
                            height: 1.50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final item in _products) _productRow(item),
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
    final thumbW = healthDp(context, 78);
    final thumbH = healthDp(context, 72);
    final url = (item.imageUrl != null && item.imageUrl!.isNotEmpty)
        ? ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId)
        : null;
    final meta = _metaParts(item);

    return InkWell(
      onTap: () => _toggleOne(item),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 20),
          vertical: healthDp(context, 16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              width: healthDp(context, 1),
              color: _kLine,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _checkSquare(selected: selected),
            SizedBox(width: healthDp(context, 14)),
            Container(
              width: thumbW,
              height: thumbH,
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: const Color(0xFFF6F6F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: url == null
                  ? Icon(
                      Icons.image_outlined,
                      color: _kMuted,
                      size: healthDp(context, 28),
                    )
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
            SizedBox(width: healthDp(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _kInk,
                      fontSize: healthSp(context, 14),
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  Row(
                    children: [
                      for (var i = 0; i < meta.length; i++) ...[
                        if (i > 0) ...[
                          SizedBox(width: healthDp(context, 5)),
                          Container(
                            width: healthDp(context, 0.5),
                            height: healthDp(context, 10),
                            color: _kMuted,
                          ),
                          SizedBox(width: healthDp(context, 5)),
                        ],
                        Flexible(
                          child: Text(
                            meta[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == 0 ? _kMuted : _kMutedOpt,
                              fontSize: healthSp(context, 10),
                              fontFamily: _kFont,
                              fontWeight: FontWeight.w500,
                              letterSpacing: i == 1 ? -0.9 : 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  Text(
                    '${PriceFormatter.format(item.totalPrice)}원',
                    style: TextStyle(
                      color: _kInk,
                      fontSize: healthSp(context, 14),
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkSquare({required bool selected}) {
    final size = healthDp(context, 20);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: selected ? _kPink : _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: healthDp(context, 14), color: _kPink)
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
            top: BorderSide(
              width: healthDp(context, 1.06),
              color: const Color(0x7FD2D2D2),
            ),
          ),
        ),
        child: Material(
          color: enabled ? _kPink : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: InkWell(
            onTap: enabled ? _onConfirm : null,
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: SizedBox(
              height: healthDp(context, 49),
              child: Center(
                child: Text(
                  enabled
                      ? '${_selectedCtIds.length}개 상품 리뷰쓰기'
                      : '상품을 선택해 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled ? Colors.white : const Color(0xFFC0B9B9),
                    fontSize: healthSp(context, 14),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w300,
                    height: 1.50,
                    letterSpacing: -0.30,
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
