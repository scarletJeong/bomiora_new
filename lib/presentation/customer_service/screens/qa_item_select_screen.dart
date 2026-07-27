import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/recent_view_service.dart';
import '../../../data/services/wish_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';
import 'qa_input_screen.dart';

enum QaItemSelectMode { product, order }

/// 상품(최근본/찜/장바구니) 또는 주문내역 선택
class QaItemSelectScreen extends StatefulWidget {
  final QaItemSelectMode mode;

  const QaItemSelectScreen({super.key, required this.mode});

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

  /// product mode tabs: 0 최근 본, 1 찜, 2 장바구니
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
      final raw = await RecentViewService.getRecentList(limit: 10);
      list = raw.map(_fromRecentMap).whereType<_SelectableItem>().toList();
    } else if (_tabIndex == 1) {
      final raw = await WishService.getWishList();
      list = raw
          .whereType<Map>()
          .map((e) => _fromWishMap(Map<String, dynamic>.from(e)))
          .whereType<_SelectableItem>()
          .toList();
    } else {
      final result = await CartService.getCart();
      final raw = result['items'] ?? result['data'] ?? [];
      if (raw is List) {
        list = raw
            .whereType<Map>()
            .map((e) => _fromCartMap(Map<String, dynamic>.from(e)))
            .whereType<_SelectableItem>()
            .toList();
      }
    }
    if (!mounted) return;
    setState(() {
      _items = list.take(10).toList();
      _loading = false;
    });
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
    final list = <_SelectableItem>[];
    for (final order in orders) {
      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          list.add(_SelectableItem(
            key: 'order_${order.odId}_${item.ctId}_${item.itId}',
            itId: item.itId,
            productKind: item.itKind,
            productName: item.itName.isNotEmpty ? item.itName : item.itSubject,
            brandName: null,
            imageUrl: item.imageUrl,
            price: item.totalPrice > 0 ? item.totalPrice : item.ctPrice,
            odId: order.odId,
            orderDate: order.orderDate,
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
        ));
      }
    }
    if (!mounted) return;
    setState(() {
      _items = list.take(10).toList();
      _loading = false;
    });
  }

  _SelectableItem? _fromRecentMap(Map<String, dynamic> m) {
    final itId = (NodeValueParser.asString(m['it_id']) ?? '').trim();
    if (itId.isEmpty) return null;
    final name = (NodeValueParser.asString(m['product_name']) ??
            NodeValueParser.asString(m['it_name']) ??
            '상품')
        .trim();
    return _SelectableItem(
      key: 'recent_$itId',
      itId: itId,
      productKind: NodeValueParser.asString(m['it_kind']) ??
          NodeValueParser.asString(m['product_kind']),
      productName: name,
      brandName: NodeValueParser.asString(m['brand_name']) ??
          NodeValueParser.asString(m['it_brand']),
      imageUrl: NodeValueParser.asString(m['image_url']) ??
          NodeValueParser.asString(m['it_img']) ??
          NodeValueParser.asString(m['it_img1']),
      price: NodeValueParser.asInt(m['product_price']) ??
          NodeValueParser.asInt(m['it_price']),
    );
  }

  _SelectableItem? _fromWishMap(Map<String, dynamic> m) {
    final itId = (NodeValueParser.asString(m['it_id']) ??
            NodeValueParser.asString(m['itId']) ??
            '')
        .trim();
    if (itId.isEmpty) return null;
    final name = (NodeValueParser.asString(m['it_name']) ??
            NodeValueParser.asString(m['product_name']) ??
            NodeValueParser.asString(m['it_subject']) ??
            '상품')
        .trim();
    return _SelectableItem(
      key: 'wish_$itId',
      itId: itId,
      productKind: NodeValueParser.asString(m['it_kind']) ??
          NodeValueParser.asString(m['product_kind']),
      productName: name,
      brandName: NodeValueParser.asString(m['it_brand']) ??
          NodeValueParser.asString(m['brand_name']),
      imageUrl: NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']) ??
          NodeValueParser.asString(m['it_img']),
      price: NodeValueParser.asInt(m['it_price']) ??
          NodeValueParser.asInt(m['product_price']),
    );
  }

  _SelectableItem? _fromCartMap(Map<String, dynamic> m) {
    final itId = (NodeValueParser.asString(m['it_id']) ??
            NodeValueParser.asString(m['itId']) ??
            '')
        .trim();
    if (itId.isEmpty) return null;
    final name = (NodeValueParser.asString(m['it_name']) ??
            NodeValueParser.asString(m['it_subject']) ??
            NodeValueParser.asString(m['product_name']) ??
            '상품')
        .trim();
    return _SelectableItem(
      key: 'cart_${NodeValueParser.asString(m['ct_id']) ?? itId}',
      itId: itId,
      productKind: NodeValueParser.asString(m['it_kind']),
      productName: name,
      brandName: NodeValueParser.asString(m['it_brand']),
      imageUrl: NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']),
      price: NodeValueParser.asInt(m['ct_price']) ??
          NodeValueParser.asInt(m['it_price']),
    );
  }

  Future<void> _onNext() async {
    final key = _selectedKey;
    if (key == null) return;
    final item = _items.cast<_SelectableItem?>().firstWhere(
          (e) => e?.key == key,
          orElse: () => null,
        );
    if (item == null) return;

    final draft = QaInquiryDraft(
      category: _isProduct ? '상품' : '주문',
      itId: item.itId,
      productKind: item.productKind,
      productName: item.productName,
      brandName: item.brandName,
      imageUrl: item.imageUrl,
      price: item.price,
      odId: item.odId,
      orderDate: item.orderDate,
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
      if (_tabIndex == 0) return '최근 2주동안 확인한 상품을 보여드려요';
      if (_tabIndex == 1) return '찜한 상품을 보여드려요';
      return '장바구니에 담긴 상품을 보여드려요';
    }
    return '최근 주문내역을 보여드려요';
  }

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
          if (_isProduct) _buildTabs(context),
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
    const labels = ['최근 본 상품', '찜한 상품', '장바구니'];
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
                _isProduct ? '선택 가능한 상품이 없습니다.' : '주문내역이 없습니다.',
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
              onTap: () => setState(() => _selectedKey = item.key),
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
              activeColor: _pink,
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
                if ((item.brandName ?? '').trim().isNotEmpty ||
                    (item.odId ?? '').trim().isNotEmpty)
                  Text(
                    (item.brandName ?? '').trim().isNotEmpty
                        ? item.brandName!.trim()
                        : '주문 ${item.odId}',
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
