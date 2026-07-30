import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/wish_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';
import 'qa_input_screen.dart';

enum QaItemSelectMode { product, order }

/// 상품(찜/장바구니) 또는 주문내역(주문·배송 / 취소) 선택
class QaItemSelectScreen extends StatefulWidget {
  final QaItemSelectMode mode;
  final String majorCategory;

  const QaItemSelectScreen({
    super.key,
    required this.mode,
    required this.majorCategory,
  });

  @override
  State<QaItemSelectScreen> createState() =>
      _QaItemSelectScreenState();
}

class _QaItemSelectScreenState extends State<QaItemSelectScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  /// product: 0 장바구니, 1 찜
  /// order: 0 주문/배송, 1 취소
  int _tabIndex = 0;
  bool _loading = true;
  String? _error;
  List<_SelectableItem> _items = [];
  String? _selectedKey;

  bool get _isProduct => widget.mode == QaItemSelectMode.product;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedKey = null;
    });
    try {
      if (_isProduct) {
        await _loadProducts();
      } else {
        await _loadOrders();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '목록을 불러오지 못했습니다.';
        _items = [];
        _loading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    List<_SelectableItem> list = [];
    if (_tabIndex == 0) {
      final result = await CartService.getCart();
      final raw = result['items'] ?? result['data'] ?? [];
      if (raw is List) {
        list = raw
            .whereType<Map>()
            .map((e) => _fromCartMap(Map<String, dynamic>.from(e)))
            .whereType<_SelectableItem>()
            .toList();
      }
      list = await _enrichMissingSubjects(list);
    } else {
      final raw = await WishService.getWishList();
      list = raw
          .whereType<Map>()
          .map((e) => _fromWishMap(Map<String, dynamic>.from(e)))
          .whereType<_SelectableItem>()
          .toList();
      list = await _enrichMissingSubjects(list);
    }
    if (!mounted) return;
    setState(() {
      _items = list.take(10).toList();
      _loading = false;
    });
  }

  /// 장바구니/찜에 it_subject가 비어 있으면 상품 상세에서 보강
  Future<List<_SelectableItem>> _enrichMissingSubjects(
    List<_SelectableItem> items,
  ) async {
    if (items.isEmpty) return items;
    final enriched = await Future.wait(items.map((item) async {
      if ((item.itSubject ?? '').trim().isNotEmpty) return item;
      final itId = (item.itId ?? '').trim();
      if (itId.isEmpty) return item;
      try {
        final product = await ProductRepository.getProductDetail(itId);
        final label = _productSubjectLabel(
          product?.itSubject,
          productKind: item.productKind ?? product?.productKind,
        );
        if (label == null || label.isEmpty) return item;
        return _SelectableItem(
          key: item.key,
          itId: item.itId,
          productKind: item.productKind,
          productName: item.productName,
          brandName: item.brandName,
          imageUrl: item.imageUrl,
          price: item.price,
          odId: item.odId,
          orderDate: item.orderDate,
          optionText: item.optionText,
          itSubject: label,
          fromCart: item.fromCart,
        );
      } catch (_) {
        return item;
      }
    }));
    return enriched;
  }

  bool _isWithinOneMonth(OrderListModel order) {
    final raw = order.orderDateTime.trim().isNotEmpty
        ? order.orderDateTime
        : order.orderDate;
    final dt = DateDisplayFormatter.tryParseYmdFlexible(raw) ??
        DateTime.tryParse(raw.replaceAll('.', '-').replaceFirst(' ', 'T'));
    if (dt == null) return false;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));
    return !dt.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
  }

  bool _isOrderShippingStatus(String odStatus) {
    final s = odStatus.trim();
    // 주문·배송 탭: 주문/배송/완료 (+ 입금·준비는 주문 진행 상태)
    return s == '주문' ||
        s == '배송' ||
        s == '완료' ||
        s == '입금' ||
        s == '준비';
  }

  bool _isCancelStatus(String odStatus) {
    final s = odStatus.trim();
    return s == '취소' || s.contains('취소');
  }

  Future<void> _loadOrders() async {
    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _error = '로그인이 필요합니다.';
        _items = [];
        _loading = false;
      });
      return;
    }
    final result = await OrderService.getOrderList(
      mbId: user.id,
      period: 0,
      status: 'all',
      page: 0,
      size: 50,
    );
    final orders = (result['orders'] as List?)?.whereType<OrderListModel>() ??
        const <OrderListModel>[];
    final filtered = orders.where((order) {
      if (!_isWithinOneMonth(order)) return false;
      if (_tabIndex == 1) return _isCancelStatus(order.odStatus);
      return _isOrderShippingStatus(order.odStatus);
    });

    final list = <_SelectableItem>[];
    for (final order in filtered) {
      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          list.add(_SelectableItem(
            key: 'order_${order.odId}_${item.ctId}_${item.itId}',
            itId: item.itId,
            productKind: item.itKind,
            productName: item.itName.isNotEmpty ? item.itName : '상품',
            brandName: null,
            imageUrl: item.imageUrl,
            price: item.totalPrice > 0 ? item.totalPrice : item.ctPrice,
            odId: order.odId,
            orderDate: order.orderDate,
            optionText: QaInquiryDraft.formatOptionText(
              ctOption: item.ctOption,
              itSubject: null,
            ),
            itSubject: item.itName.isNotEmpty &&
                    item.itSubject.trim().isNotEmpty &&
                    item.itSubject.trim() != item.itName.trim()
                ? item.itSubject.trim()
                : null,
          ));
        }
      } else {
        list.add(_SelectableItem(
          key: 'order_${order.odId}',
          itId: null,
          productName: order.firstProductName ?? '주문 상품',
          brandName: null,
          imageUrl: null,
          price: order.firstProductPrice ?? order.totalPrice,
          odId: order.odId,
          orderDate: order.orderDate,
          optionText: order.firstProductOption,
        ));
      }
    }
    if (!mounted) return;
    setState(() {
      _items = list.take(10).toList();
      _loading = false;
    });
  }

  _SelectableItem? _fromWishMap(Map<String, dynamic> m) {
    final itId = (NodeValueParser.asString(m['it_id']) ??
            NodeValueParser.asString(m['itId']) ??
            '')
        .trim();
    if (itId.isEmpty) return null;
    final name = (NodeValueParser.asString(m['it_name']) ??
            NodeValueParser.asString(m['product_name']) ??
            '상품')
        .trim();
    final displayName = name.isNotEmpty ? name : '상품';
    return _SelectableItem(
      key: 'wish_$itId',
      itId: itId,
      productKind: NodeValueParser.asString(m['it_kind']) ??
          NodeValueParser.asString(m['product_kind']),
      productName: displayName,
      brandName: NodeValueParser.asString(m['it_brand']) ??
          NodeValueParser.asString(m['brand_name']) ??
          NodeValueParser.asString(m['it_maker']) ??
          NodeValueParser.asString(m['it_origin']),
      imageUrl: NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']) ??
          NodeValueParser.asString(m['it_img']),
      price: NodeValueParser.asInt(m['it_price']) ??
          NodeValueParser.asInt(m['product_price']),
      itSubject: _productSubjectLabel(
        NodeValueParser.asString(m['it_subject']) ??
            NodeValueParser.asString(m['itSubject']),
        productKind: NodeValueParser.asString(m['it_kind']) ??
            NodeValueParser.asString(m['product_kind']),
      ),
    );
  }

  _SelectableItem? _fromCartMap(Map<String, dynamic> m) {
    final cartItem = CartItem.fromJson(m);
    final itId = cartItem.itId.trim();
    if (itId.isEmpty) return null;
    final name = cartItem.itName.trim().isNotEmpty
        ? cartItem.itName.trim()
        : '상품';
    final itSubjectRaw = (cartItem.itSubject ??
            NodeValueParser.asString(m['it_subject']) ??
            NodeValueParser.asString(m['itSubject']) ??
            '')
        .trim();
    final subjectLabel = _productSubjectLabel(
      itSubjectRaw,
      productKind: cartItem.ctKind,
    );
    final optionText = QaInquiryDraft.formatOptionText(
      ctOption: cartItem.ctOption,
      itSubject: null,
    );
    return _SelectableItem(
      key: 'cart_${cartItem.ctId > 0 ? cartItem.ctId : itId}',
      itId: itId,
      productKind: cartItem.ctKind,
      productName: name,
      brandName: NodeValueParser.asString(m['it_brand']) ??
          NodeValueParser.asString(m['brand_name']) ??
          NodeValueParser.asString(m['it_maker']) ??
          NodeValueParser.asString(m['it_origin']),
      imageUrl: cartItem.imageUrl ??
          NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']),
      price: cartItem.ctPrice > 0 ? cartItem.ctPrice : null,
      optionText: optionText,
      itSubject: subjectLabel,
      fromCart: true,
    );
  }

  /// draft용 it_subject 라벨 (선택 목록 UI에는 표시하지 않음)
  String? _productSubjectLabel(String? raw, {String? productKind}) {
    final subject = stripProductCatalogHtml(raw);
    if (isBomioraHospitalProductSubject(subject)) {
      return '보미오라 한의원';
    }
    if (shouldShowProductCardSubject(subject)) {
      return subject;
    }
    final kind = (productKind ?? '').trim().toLowerCase();
    if (kind.isNotEmpty && kind != 'general') {
      return '보미오라 한의원';
    }
    return subject.isNotEmpty ? subject : null;
  }

  Future<void> _onNext() async {
    final key = _selectedKey;
    if (key == null) return;
    final item = _items.cast<_SelectableItem?>().firstWhere(
          (e) => e?.key == key,
          orElse: () => null,
        );
    if (item == null) return;

    final tabLabels = _tabLabels;
    final draft = QaInquiryDraft(
      category: _isProduct ? '상품' : '주문',
      majorCategory: widget.majorCategory,
      itId: item.itId,
      productKind: item.productKind,
      productName: item.productName,
      brandName: item.brandName,
      imageUrl: item.imageUrl,
      price: item.price,
      odId: item.odId,
      orderDate: item.orderDate,
      optionText: item.optionText,
      itSubject: item.itSubject,
      selectTabLabel: (_tabIndex >= 0 && _tabIndex < tabLabels.length)
          ? tabLabels[_tabIndex]
          : null,
    );

    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => QaInputScreen(draft: draft),
      ),
    );
    if (mounted && result != null) Navigator.pop(context, result);
  }

  String get _headerTitle {
    if (_isProduct) return '문의하실 상품을 선택해주세요';
    return '문의하실 주문을 선택해주세요';
  }

  String get _headerSub {
    if (_isProduct) {
      if (_tabIndex == 0) return '장바구니에 담긴 상품을 보여드려요';
      return '찜한 상품을 보여드려요';
    }
    if (_tabIndex == 1) return '최근 1개월 내 취소한 주문을 보여드려요';
    return '최근 1개월 내 주문·배송 내역을 보여드려요';
  }

  List<String> get _tabLabels => _isProduct
      ? const ['장바구니', '찜한 상품']
      : const ['주문/배송', '취소'];

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(
        title: '문의하기',
        centerTitle: false,
      ),
      child: Column(
        children: [
          _buildTabs(context),
          Expanded(
            child: _buildBody(context),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 0),
                healthDp(context, 27),
                healthDp(context, 5),
              ),
              child: GestureDetector(
                onTap: _selectedKey == null ? null : _onNext,
                child: Container(
                  width: double.infinity,
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _selectedKey == null
                        ? _pink.withValues(alpha: 0.4)
                        : _pink,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                    ),
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: healthSp(context, 16),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final labels = _tabLabels;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_tabIndex == i) return;
                    setState(() => _tabIndex = i);
                    _load();
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          healthDp(context, 5),
                          0,
                          healthDp(context, 1),
                        ),
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _tabIndex == i ? _pink : _muted,
                            fontSize: healthSp(context, 13),
                            fontFamily: _font,
                            fontWeight: _tabIndex == i
                                ? FontWeight.w500
                                : FontWeight.w300,
                          ),
                        ),
                      ),
                      Container(
                        height: healthDp(context, 1.3),
                        color: _tabIndex == i ? _pink : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Container(height: healthDp(context, 1), color: _border),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _pink));
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 14),
            fontFamily: _font,
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 16),
        healthDp(context, 27),
        healthDp(context, 5),
      ),
      children: [
        Text(
          _headerTitle,
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 18),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 2)),
        Text(
          _headerSub,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: healthDp(context, 16)),
        if (_items.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 48)),
            child: Center(
              child: Text(
                _isProduct
                    ? '선택 가능한 상품이 없습니다.'
                    : (_tabIndex == 1
                        ? '최근 1개월 내 취소 주문이 없습니다.'
                        : '최근 1개월 내 주문·배송 내역이 없습니다.'),
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                ),
              ),
            ),
          )
        else
          for (final item in _items) ...[
            _SelectableRow(
              item: item,
              selected: _selectedKey == item.key,
              onTap: () => setState(() {
                _selectedKey =
                    _selectedKey == item.key ? null : item.key;
              }),
            ),
            SizedBox(height: healthDp(context, 12)),
          ],
      ],
    );
  }
}

class _SelectableItem {
  final String key;
  final String? itId;
  final String? productKind;
  final String productName;
  final String? brandName;
  final String? imageUrl;
  final int? price;
  final String? odId;
  final String? orderDate;
  final String? optionText;
  final String? itSubject;
  final bool fromCart;

  const _SelectableItem({
    required this.key,
    this.itId,
    this.productKind,
    required this.productName,
    this.brandName,
    this.imageUrl,
    this.price,
    this.odId,
    this.orderDate,
    this.optionText,
    this.itSubject,
    this.fromCart = false,
  });
}

class _SelectableRow extends StatelessWidget {
  final _SelectableItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0xFFD2D2D2);
  static const Color _pink = Color(0xFFFF5A8D);
  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    final thumb = healthDp(context, 72);
    final imageUrl = (item.imageUrl ?? '').trim();

    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: healthDp(context, 22),
            height: healthDp(context, 22),
            child: Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              checkColor: _pink,
              fillColor: WidgetStateProperty.resolveWith((_) => Colors.white),
              side: BorderSide(
                color: _border,
                width: healthDp(context, 1.5),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
          ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 6)),
            child: Container(
              width: thumb,
              height: thumb,
              color: const Color(0xFFE8E8E8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      ImageUrlHelper.getImageUrl(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade500,
                        size: healthDp(context, 28),
                      ),
                    )
                  : Icon(
                      Icons.image_outlined,
                      color: Colors.grey.shade500,
                      size: healthDp(context, 28),
                    ),
            ),
          ),
          SizedBox(width: healthDp(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 선택 목록에서는 it_subject 비표시 — 브랜드 또는 주문번호만
                if ((item.odId ?? '').trim().isNotEmpty)
                  Text(
                    '주문 ${item.odId}',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 11),
                      fontFamily: _font,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if ((item.brandName ?? '').trim().isNotEmpty)
                  Text(
                    item.brandName!.trim(),
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 11),
                      fontFamily: _font,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: healthDp(context, 2)),
                Text(
                  item.productName,
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 13),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((item.optionText ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    item.optionText!.trim(),
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 11),
                      fontFamily: _font,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: healthDp(context, 4)),
                Text(
                  '${PriceFormatter.format(item.price)}원',
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 13),
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
