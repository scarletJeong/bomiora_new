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
import '../../shopping/widgets/supply_add_expand_block.dart';
import '../../user/delivery/widgets/order_item_subject_groups.dart';
import '../models/qa_inquiry_draft.dart';

enum QaItemSelectTab { order, cancel, cart, wish }

class QaItemSelectScreen extends StatefulWidget {
  final String majorCategory;
  final String? detailCategory;

  const QaItemSelectScreen({
    super.key,
    required this.majorCategory,
    this.detailCategory,
  });

  @override
  State<QaItemSelectScreen> createState() => _QaItemSelectScreenState();
}

class _QaItemSelectScreenState extends State<QaItemSelectScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const String _font = 'Gmarket Sans TTF';

  int _tabIndex = 0;
  bool _loading = true;
  String? _error;
  List<_SelectableItem> _items = [];
  List<_OrderGroup> _orderGroups = [];
  final Set<String> _selectedKeys = {};
  final Set<String> _expandedExtraKeys = {};

  QaItemSelectTab get _currentTab => QaItemSelectTab.values[_tabIndex];

  bool get _isOrderTab =>
      _currentTab == QaItemSelectTab.order ||
      _currentTab == QaItemSelectTab.cancel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedKeys.clear();
      _expandedExtraKeys.clear();
    });
    try {
      if (_isOrderTab) {
        await _loadOrders();
      } else {
        await _loadProducts();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '목록을 불러오지 못했습니다.';
        _items = [];
        _orderGroups = [];
        _loading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    List<_SelectableItem> list = [];
    if (_currentTab == QaItemSelectTab.cart) {
      final result = await CartService.getCart();
      final raw = result['items'] ?? result['data'] ?? [];
      if (raw is List) {
        list = raw
            .whereType<Map>()
            .map((e) => _fromCartMap(Map<String, dynamic>.from(e)))
            .whereType<_SelectableItem>()
            .toList();
      }
      list = _groupCartExtras(list);
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
      _items = list;
      _orderGroups = [];
      _loading = false;
    });
  }

  List<_SelectableItem> _groupCartExtras(List<_SelectableItem> items) {
    final extrasByParent = <String, List<_SelectableItem>>{};
    final mains = <_SelectableItem>[];
    for (final item in items) {
      final parent = (item.parentItId ?? '').trim();
      if (parent.isNotEmpty) {
        extrasByParent.putIfAbsent(parent, () => []).add(item);
      } else {
        mains.add(item);
      }
    }
    return [
      for (final main in mains)
        main.copyWith(extras: extrasByParent[main.itId ?? ''] ?? const []),
    ];
  }

  Future<List<_SelectableItem>> _enrichMissingSubjects(
    List<_SelectableItem> items,
  ) async {
    if (items.isEmpty) return items;
    Future<_SelectableItem> enrich(_SelectableItem item) async {
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
        return item.copyWith(itSubject: label);
      } catch (_) {
        return item;
      }
    }

    return Future.wait(items.map((item) async {
      final main = await enrich(item);
      if (main.extras.isEmpty) return main;
      final extras = await Future.wait(main.extras.map(enrich));
      return main.copyWith(extras: extras);
    }));
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
    return s == '주문' ||
        s == '배송' ||
        s == '완료' ||
        s == '입금' ||
        s == '준비';
  }

  bool _isCancelExchangeRefund(OrderListModel order) {
    final status = '${order.odStatus} ${order.displayStatus}';
    return status.contains('취소') ||
        status.contains('교환') ||
        status.contains('환불') ||
        status.contains('반품');
  }

  Future<void> _loadOrders() async {
    final user = await AuthService.getUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _error = '로그인이 필요합니다.';
        _items = [];
        _orderGroups = [];
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
      if (_currentTab == QaItemSelectTab.cancel) {
        return _isCancelExchangeRefund(order);
      }
      return _isOrderShippingStatus(order.odStatus);
    });

    final groups = <_OrderGroup>[];
    for (final order in filtered) {
      final products = <_SelectableItem>[];
      if (order.items.isNotEmpty) {
        final supply = groupOrderItemsWithSupply(order.items);
        for (final g in supply) {
          products.add(
            _fromOrderItem(order, g.parent, extras: [
              for (final child in g.children) _fromOrderItem(order, child),
            ]),
          );
        }
      } else {
        products.add(_SelectableItem(
          key: 'order_${order.odId}',
          productName: order.firstProductName ?? '주문 상품',
          price: order.firstProductPrice ?? order.totalPrice,
          odId: order.odId,
          orderDate: order.orderDate,
          optionParts: _optionParts(
            qty: 1,
            optionText: order.firstProductOption,
          ),
        ));
      }
      groups.add(_OrderGroup(odId: order.odId, products: products));
    }
    if (!mounted) return;
    setState(() {
      _orderGroups = groups;
      _items = [];
      _loading = false;
    });
  }

  _SelectableItem _fromOrderItem(
    OrderListModel order,
    OrderItem item, {
    List<_SelectableItem> extras = const [],
  }) {
    final title = item.itName.isNotEmpty ? item.itName : '상품';
    final optionParts = [
      '수량: ${item.ctQty}',
      ...filterOptionPartsAgainstTitle(
        title: title,
        rawOption: item.ctOption ?? '',
      ),
    ];
    return _SelectableItem(
      key: 'order_${order.odId}_${item.ctId}_${item.itId}',
      itId: item.itId,
      productKind: item.ctKind ?? item.itKind,
      productName: title,
      imageUrl: item.imageUrl,
      price: item.totalPrice > 0 ? item.totalPrice : item.ctPrice,
      odId: order.odId,
      orderDate: order.orderDate,
      qty: item.ctQty,
      optionParts: optionParts,
      itSubject: item.itName.isNotEmpty &&
              item.itSubject.trim().isNotEmpty &&
              item.itSubject.trim() != item.itName.trim()
          ? item.itSubject.trim()
          : null,
      extras: extras,
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
            '상품')
        .trim();
    return _SelectableItem(
      key: 'wish_$itId',
      itId: itId,
      productKind: NodeValueParser.asString(m['it_kind']) ??
          NodeValueParser.asString(m['product_kind']),
      productName: name.isNotEmpty ? name : '상품',
      brandName: NodeValueParser.asString(m['it_brand']) ??
          NodeValueParser.asString(m['brand_name']) ??
          NodeValueParser.asString(m['it_maker']) ??
          NodeValueParser.asString(m['it_origin']),
      imageUrl: NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']) ??
          NodeValueParser.asString(m['it_img']),
      price: NodeValueParser.asInt(m['it_price']) ??
          NodeValueParser.asInt(m['product_price']),
      showOptions: false,
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
      price: cartItem.lineAmount > 0 ? cartItem.lineAmount : cartItem.ctPrice,
      qty: cartItem.ctQty,
      optionParts: _optionParts(qty: cartItem.ctQty, optionText: optionText),
      parentItId: cartItem.parentItId,
      fromCart: true,
      itSubject: _productSubjectLabel(
        cartItem.itSubject,
        productKind: cartItem.ctKind,
      ),
    );
  }

  List<String> _optionParts({required int qty, String? optionText}) {
    final parts = <String>['수량: $qty'];
    final raw = (optionText ?? '').trim();
    if (raw.isEmpty) return parts;
    parts.addAll(
      raw
          .split(RegExp(r'\s*\|\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e != '수량: $qty'),
    );
    return parts;
  }

  String? _productSubjectLabel(String? raw, {String? productKind}) {
    final subject = stripProductCatalogHtml(raw);
    if (isBomioraHospitalProductSubject(subject)) return '보미오라 한의원';
    if (shouldShowProductCardSubject(subject)) return subject;
    final kind = (productKind ?? '').trim().toLowerCase();
    if (kind.isNotEmpty && kind != 'general') return '보미오라 한의원';
    return subject.isNotEmpty ? subject : null;
  }

  _SelectableItem? _findByKey(String key) {
    _SelectableItem? match(List<_SelectableItem> items) {
      for (final item in items) {
        if (item.key == key) return item;
        for (final extra in item.extras) {
          if (extra.key == key) return extra;
        }
      }
      return null;
    }

    return match(_items) ??
        match([for (final g in _orderGroups) ...g.products]);
  }

  Iterable<String> _keysOfItem(_SelectableItem item) sync* {
    yield item.key;
    for (final extra in item.extras) {
      yield extra.key;
    }
  }

  List<String> _keysOfGroup(_OrderGroup group) => [
        for (final product in group.products) ..._keysOfItem(product),
      ];

  bool _isGroupFullySelected(_OrderGroup group) {
    final keys = _keysOfGroup(group);
    return keys.isNotEmpty && keys.every(_selectedKeys.contains);
  }

  void _clearKeysOutsideOrder(String? odId) {
    _selectedKeys.removeWhere((key) => _findByKey(key)?.odId != odId);
  }

  void _toggleOrderGroup(_OrderGroup group) {
    final keys = _keysOfGroup(group);
    setState(() {
      if (_isGroupFullySelected(group)) {
        _selectedKeys.removeAll(keys);
      } else {
        _selectedKeys
          ..clear()
          ..addAll(keys);
      }
    });
  }

  void _toggleItem(_SelectableItem item) {
    setState(() {
      if (!_isOrderTab) {
        if (_selectedKeys.contains(item.key)) {
          _selectedKeys.clear();
        } else {
          _selectedKeys
            ..clear()
            ..add(item.key);
        }
        return;
      }

      final keys = _keysOfItem(item).toList();
      final selected = keys.every(_selectedKeys.contains);
      if (selected) {
        _selectedKeys.removeAll(keys);
      } else {
        _clearKeysOutsideOrder(item.odId);
        _selectedKeys.addAll(keys);
      }
    });
  }

  List<_SelectableItem> _selectedParents() {
    final out = <_SelectableItem>[];
    void collect(List<_SelectableItem> items) {
      for (final item in items) {
        if (_selectedKeys.contains(item.key)) {
          out.add(item);
          continue;
        }
        for (final extra in item.extras) {
          if (_selectedKeys.contains(extra.key)) out.add(extra);
        }
      }
    }

    if (_isOrderTab) {
      for (final group in _orderGroups) {
        collect(group.products);
      }
      if (out.isEmpty) return out;
      final odId = (out.first.odId ?? '').trim();
      return out
          .where((e) => (e.odId ?? '').trim() == odId)
          .toList();
    }

    collect(_items);
    if (out.isEmpty) return out;
    return [out.first];
  }

  QaInquiryCardItem _toCardItem(_SelectableItem item) {
    return QaInquiryCardItem(
      name: item.productName,
      vendor: QaInquiryDraft.vendorLabel(
        brandName: item.brandName,
        itSubject: item.itSubject,
        productKind: item.productKind,
      ),
      imageUrl: item.imageUrl,
      price: item.price,
      qty: item.qty,
      optionText: item.optionText,
      showOptions: item.showOptions && _currentTab != QaItemSelectTab.wish,
      isHerbal: QaInquiryDraft.isHerbalProduct(
        item.productKind,
        item.itSubject,
      ),
      extras: [
        for (final extra in item.extras) _toCardItem(extra),
      ],
    );
  }

  void _onNext() {
    final selected = _selectedParents();
    if (selected.isEmpty) return;
    final item = selected.first;
    Navigator.pop(
      context,
      QaInquiryDraft(
        category: _isOrderTab ? '주문' : '상품',
        majorCategory: widget.majorCategory,
        detailCategory: widget.detailCategory,
        itId: item.itId,
        productName: item.productName,
        brandName: item.brandName,
        imageUrl: item.imageUrl,
        price: item.price,
        odId: item.odId,
        orderDate: item.orderDate,
        optionText: item.optionText,
        itSubject: item.itSubject,
        selectTabLabel: _tabLabels[_tabIndex],
        cardItems: selected.map(_toCardItem).toList(),
      ),
    );
  }

  List<String> get _tabLabels => const [
        '주문/배송',
        '취소/교환/반품',
        '장바구니',
        '찜한상품',
      ];

  String get _emptyText {
    switch (_currentTab) {
      case QaItemSelectTab.cart:
      case QaItemSelectTab.wish:
        return '선택 가능한 상품이 없습니다.';
      case QaItemSelectTab.cancel:
        return '최근 1개월 내 취소·교환·반품 내역이 없습니다.';
      case QaItemSelectTab.order:
        return '최근 1개월 내 주문·배송 내역이 없습니다.';
    }
  }

  String get _headerSub {
    switch (_currentTab) {
      case QaItemSelectTab.cart:
        return '장바구니에 담긴 상품을 보여드려요';
      case QaItemSelectTab.wish:
        return '찜한 상품을 보여드려요';
      case QaItemSelectTab.order:
        return '최근 1달 동안 주문한 상품을 보여드려요';
      case QaItemSelectTab.cancel:
        return '최근 1달 동안 취소·교환·반품한 상품을 보여드려요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 20),
                healthDp(context, 10),
                healthDp(context, 12),
                healthDp(context, 0),
              ),
              child: Row(
                children: [
                  Text(
                    '상품선택',
                    style: TextStyle(
                      color: _ink,
                      fontSize: healthSp(context, 17),
                      fontFamily: _font,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: healthDp(context, 22)),
                  ),
                ],
              ),
            ),
          ),
          _buildTabs(context),
          Expanded(child: _buildBody(context)),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 20),
                healthDp(context, 8),
                healthDp(context, 20),
                healthDp(context, 5),
              ),
              child: GestureDetector(
                onTap: _selectedKeys.isEmpty ? null : _onNext,
                child: Container(
                  width: double.infinity,
                  height: healthDp(context, 45),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _selectedKeys.isEmpty
                        ? _pink.withValues(alpha: 0.4)
                        : _pink,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 8)),
                    ),
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: healthSp(context, 15),
                      fontFamily: _font,
                      fontWeight: FontWeight.w300,
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
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 14)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabLabels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_tabIndex == i) return;
                    setState(() => _tabIndex = i);
                    _load();
                  },
                  child: Container(
                    padding: EdgeInsets.only(
                      top: healthDp(context, 6),
                      bottom: healthDp(context, 6),
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: healthDp(context, 2),
                          color: _tabIndex == i
                              ? const Color(0xFFFF5A8D)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _tabLabels[i],
                        style: TextStyle(
                          color: _tabIndex == i
                              ? const Color(0xFFFF5A8D)
                              : const Color(0xFF999999),
                          fontSize: healthSp(context, 13),
                          fontFamily: _font,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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

    final hasItems = _isOrderTab ? _orderGroups.isNotEmpty : _items.isNotEmpty;

    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 20),
            healthDp(context, 10),
            healthDp(context, 20),
            healthDp(context, 10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문의하실 상품을 선택해 주세요.',
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 20),
                  fontFamily: _font,
                  fontWeight: FontWeight.w300,
                  height: 1.4,
                ),
              ),
              SizedBox(height: healthDp(context, 6)),
              Text(
                _headerSub,
                style: TextStyle(
                  color: const Color(0xFFB5B3B3),
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!hasItems)
          Padding(
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 48)),
            child: Center(
              child: Text(
                _emptyText,
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                ),
              ),
            ),
          )
        else if (_isOrderTab)
          for (final group in _orderGroups) _buildOrderGroup(group)
        else
          for (final item in _items) _buildProductRow(item),
      ],
    );
  }

  Widget _buildOrderGroup(_OrderGroup group) {
    return Column(
      children: [
        _OrderHeaderRow(
          odId: group.odId,
          selected: _isGroupFullySelected(group),
          onTap: () => _toggleOrderGroup(group),
        ),
        for (final product in group.products) _buildProductRow(product),
      ],
    );
  }

  Widget _buildProductRow(_SelectableItem item) {
    final expanded = _expandedExtraKeys.contains(item.key);
    final extraInset = healthDp(context, 34);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 16),
        healthDp(context, 20),
        healthDp(context, 16),
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductSelectRow(
            item: item,
            selected: _selectedKeys.contains(item.key),
            showOptions: item.showOptions && _currentTab != QaItemSelectTab.wish,
            embedded: true,
            onTap: () => _toggleItem(item),
          ),
          if (item.extras.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            Padding(
              padding: EdgeInsets.only(left: extraInset),
              child: _ExtraDropdown(
                extras: item.extras,
                expanded: expanded,
                onToggle: () => setState(() {
                  if (expanded) {
                    _expandedExtraKeys.remove(item.key);
                  } else {
                    _expandedExtraKeys.add(item.key);
                  }
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderGroup {
  const _OrderGroup({required this.odId, required this.products});
  final String odId;
  final List<_SelectableItem> products;
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
  final int qty;
  final List<String> optionParts;
  final String? itSubject;
  final String? parentItId;
  final bool fromCart;
  final bool showOptions;
  final List<_SelectableItem> extras;

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
    this.qty = 1,
    this.optionParts = const [],
    this.itSubject,
    this.parentItId,
    this.fromCart = false,
    this.showOptions = true,
    this.extras = const [],
  });

  String? get optionText {
    final opts = optionParts.where((e) => !e.startsWith('수량:')).toList();
    if (opts.isEmpty) return null;
    return opts.join(' | ');
  }

  _SelectableItem copyWith({
    String? itSubject,
    List<_SelectableItem>? extras,
  }) {
    return _SelectableItem(
      key: key,
      itId: itId,
      productKind: productKind,
      productName: productName,
      brandName: brandName,
      imageUrl: imageUrl,
      price: price,
      odId: odId,
      orderDate: orderDate,
      qty: qty,
      optionParts: optionParts,
      itSubject: itSubject ?? this.itSubject,
      parentItId: parentItId,
      fromCart: fromCart,
      showOptions: showOptions,
      extras: extras ?? this.extras,
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = healthDp(context, 20);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: selected
                ? const Color(0xFFFF5A8D)
                : const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
        ),
      ),
      child: selected
          ? Icon(
              Icons.check,
              size: healthDp(context, 14),
              color: const Color(0xFFFF5A8D),
            )
          : null,
    );
  }
}

class _OrderHeaderRow extends StatelessWidget {
  const _OrderHeaderRow({
    required this.odId,
    required this.selected,
    required this.onTap,
  });

  final String odId;
  final bool selected;
  final VoidCallback onTap;

  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 20),
          healthDp(context, 14),
          healthDp(context, 20),
          healthDp(context, 10),
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF5F5F5)),
          ),
        ),
        child: Row(
          children: [
            _CheckBox(selected: selected),
            SizedBox(width: healthDp(context, 10)),
            Text(
              '주문번호',
              style: TextStyle(
                color: const Color(0xFF999999),
                fontSize: healthSp(context, 12),
                fontFamily: _font,
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: Text(
                odId,
                style: TextStyle(
                  color: const Color(0xFF555555),
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSelectRow extends StatelessWidget {
  const _ProductSelectRow({
    required this.item,
    required this.selected,
    required this.onTap,
    this.showOptions = true,
    this.compact = false,
    this.embedded = false,
  });

  final _SelectableItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool showOptions;
  final bool compact;
  final bool embedded;

  static const Color _ink = Color(0xFF1A1A1E);
  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    final imageUrl = (item.imageUrl ?? '').trim();
    final thumbW = healthDp(context, compact ? 72 : 78);
    final thumbH = healthDp(context, 72);
    final parts = showOptions
        ? (item.optionParts.isNotEmpty
            ? item.optionParts
            : ['수량: ${item.qty}'])
        : const <String>[];

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: embedded
            ? EdgeInsets.symmetric(vertical: healthDp(context, compact ? 8 : 0))
            : EdgeInsets.symmetric(
                horizontal: healthDp(context, compact ? 0 : 20),
                vertical: healthDp(context, 16),
              ),
        decoration: embedded
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF5F5F5)),
                ),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CheckBox(selected: selected),
            SizedBox(width: healthDp(context, 14)),
            ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
              child: Container(
                width: thumbW,
                height: thumbH,
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
            SizedBox(width: healthDp(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: TextStyle(
                      color: _ink,
                      fontSize: healthSp(context, 14),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parts.isNotEmpty) ...[
                    SizedBox(height: healthDp(context, 10)),
                    _OptionMetaRow(parts: parts),
                  ],
                  SizedBox(height: healthDp(context, 10)),
                  Text(
                    '${PriceFormatter.format(item.price)}원',
                    style: TextStyle(
                      color: _ink,
                      fontSize: healthSp(context, 14),
                      fontFamily: _font,
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
}

class _OptionMetaRow extends StatelessWidget {
  const _OptionMetaRow({required this.parts});

  final List<String> parts;

  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: healthDp(context, 5),
      runSpacing: healthDp(context, 4),
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Container(
              width: healthDp(context, 0.5),
              height: healthDp(context, 10),
              color: const Color(0xFF898686),
            ),
          Text(
            parts[i],
            style: TextStyle(
              color: i == 1
                  ? const Color(0xFF898383)
                  : const Color(0xFF898686),
              fontSize: healthSp(context, 10),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              letterSpacing: i == 1 ? -0.9 : 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExtraDropdown extends StatelessWidget {
  const _ExtraDropdown({
    required this.extras,
    required this.expanded,
    required this.onToggle,
  });

  final List<_SelectableItem> extras;
  final bool expanded;
  final VoidCallback onToggle;

  String _optionLine(_SelectableItem extra) {
    final opts = extra.optionParts
        .where((e) => !e.startsWith('수량:'))
        .toList();
    if (opts.isEmpty) return extra.qty > 0 ? '수량: ${extra.qty}' : '';
    return opts.join(' ㅣ ');
  }

  @override
  Widget build(BuildContext context) {
    return SupplyAddExpandBlock(
      count: extras.length,
      expanded: expanded,
      onToggle: onToggle,
      children: [
        for (var i = 0; i < extras.length; i++)
          SupplyAddReadOnlyRow(
            name: extras[i].productName,
            optionLine: _optionLine(extras[i]),
            price: extras[i].price,
            imageUrl: extras[i].imageUrl,
            showDivider: i < extras.length - 1,
          ),
      ],
    );
  }
}
