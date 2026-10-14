import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/wish_service.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../shopping/widgets/supply_add_expand_block.dart';
import '../../user/delivery/widgets/order_item_subject_groups.dart';
import '../models/qa_inquiry_draft.dart';
import '../models/qa_maker_resolver.dart';
import '../widgets/qa_detail_product_card.dart';

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
  static const String _font = 'Gmarket Sans TTF';

  int _tabIndex = 0;
  bool _loading = true;
  String? _error;
  List<_SelectableItem> _items = [];
  List<_OrderGroup> _orderGroups = [];
  final Set<String> _selectedKeys = {};

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
    } else {
      final raw = await WishService.getWishList();
      list = raw
          .whereType<Map>()
          .map((e) => _fromWishMap(Map<String, dynamic>.from(e)))
          .whereType<_SelectableItem>()
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _items = list;
      _orderGroups = [];
      _loading = false;
    });
    unawaited(_fillMissingMakers());
  }

  Future<void> _fillMissingMakers() async {
    final ids = <String>{};
    void collect(List<_SelectableItem> items) {
      for (final item in items) {
        final id = (item.itId ?? '').trim();
        if (id.isNotEmpty && (item.brandName ?? '').trim().isEmpty) {
          ids.add(id);
        }
        collect(item.extras);
      }
    }

    collect(_items);
    for (final group in _orderGroups) {
      collect(group.products);
    }
    if (ids.isEmpty) return;
    final labels = await QaMakerResolver.labelsFor(ids);
    if (!mounted || labels.isEmpty) return;
    setState(() {
      _items = _applyMakers(_items, labels);
      _orderGroups = [
        for (final group in _orderGroups)
          _OrderGroup(
            odId: group.odId,
            products: _applyMakers(group.products, labels),
          ),
      ];
    });
  }

  List<_SelectableItem> _applyMakers(
    List<_SelectableItem> items,
    Map<String, String> labels,
  ) {
    return [
      for (final item in items)
        item.withMaker(
          (item.brandName ?? '').trim().isNotEmpty
              ? item.brandName
              : labels[(item.itId ?? '').trim()],
          extras: _applyMakers(item.extras, labels),
        ),
    ];
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
    return s == '주문' || s == '배송' || s == '완료' || s == '입금' || s == '준비';
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
      period: 1,
      status: 'all',
      page: 0,
      size: 30,
      lite: true,
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
            optionText: ProductOption.visibleLabel(
              ctOption: order.firstProductOption,
            ),
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
    unawaited(_fillMissingMakers());
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
        rawOption: item.displayOptionText,
      ),
    ];
    return _SelectableItem(
      key: 'order_${order.odId}_${item.ctId}_${item.itId}',
      itId: item.itId,
      productKind: item.ctKind ?? item.itKind,
      productName: title,
      brandName: QaInquiryDraft.makerLabel(
        itSubject: item.itSubject,
        productName: title,
      ),
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
    final kind = (NodeValueParser.asString(m['wi_it_kind']) ??
            NodeValueParser.asString(m['it_kind']) ??
            NodeValueParser.asString(m['product_kind']) ??
            '')
        .trim()
        .toLowerCase();
    if (kind == 'content') return null;
    final itId = (NodeValueParser.asString(m['it_id']) ??
            NodeValueParser.asString(m['itId']) ??
            '')
        .trim();
    if (itId.isEmpty) return null;
    final name = (NodeValueParser.asString(m['it_name']) ??
            NodeValueParser.asString(m['product_name']) ??
            '')
        .trim();
    if (name.isEmpty) return null;
    return _SelectableItem(
      key: 'wish_$itId',
      itId: itId,
      productKind: NodeValueParser.asString(m['it_kind']) ??
          NodeValueParser.asString(m['product_kind']),
      productName: name,
      brandName: QaInquiryDraft.makerLabel(
        itSubject: NodeValueParser.asString(m['it_subject']) ??
            NodeValueParser.asString(m['itSubject']),
        productName: name,
      ),
      imageUrl: NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']) ??
          NodeValueParser.asString(m['it_img']),
      price: NodeValueParser.asInt(m['it_price']) ??
          NodeValueParser.asInt(m['product_price']),
      showOptions: false,
      itSubject: _productSubjectLabel(
        NodeValueParser.asString(m['it_subject']) ??
            NodeValueParser.asString(m['itSubject']),
      ),
    );
  }

  _SelectableItem? _fromCartMap(Map<String, dynamic> m) {
    final cartItem = CartItem.fromJson(m);
    final itId = cartItem.itId.trim();
    if (itId.isEmpty) return null;
    final name =
        cartItem.itName.trim().isNotEmpty ? cartItem.itName.trim() : '상품';
    final optionText = QaInquiryDraft.formatOptionText(
      ctOption: cartItem.ctOption,
      itSubject: null,
    );
    return _SelectableItem(
      key: 'cart_${cartItem.ctId > 0 ? cartItem.ctId : itId}',
      itId: itId,
      productKind: cartItem.ctKind,
      productName: name,
      brandName: QaInquiryDraft.makerLabel(
        itSubject: cartItem.itSubject,
        productName: name,
      ),
      imageUrl: cartItem.imageUrl ??
          NodeValueParser.asString(m['it_img1']) ??
          NodeValueParser.asString(m['image_url']),
      price: cartItem.lineAmount > 0 ? cartItem.lineAmount : cartItem.ctPrice,
      qty: cartItem.ctQty,
      optionParts: _optionParts(qty: cartItem.ctQty, optionText: optionText),
      parentItId: cartItem.parentItId,
      fromCart: true,
      itSubject: _productSubjectLabel(cartItem.itSubject),
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

  String? _productSubjectLabel(String? raw) {
    final subject = stripProductCatalogHtml(raw);
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
      return out.where((e) => (e.odId ?? '').trim() == odId).toList();
    }

    collect(_items);
    if (out.isEmpty) return out;
    return [out.first];
  }

  QaInquiryCardItem _toCardItem(_SelectableItem item) {
    return QaInquiryCardItem(
      name: item.productName,
      vendor: QaInquiryDraft.vendorLabel(
        itSubject: item.itSubject,
      ),
      maker: (item.brandName ?? '').trim().isEmpty ? null : item.brandName!.trim(),
      imageUrl: item.imageUrl,
      price: item.price,
      qty: item.qty,
      optionText: item.optionText,
      showOptions: item.showOptions && _currentTab != QaItemSelectTab.wish,
      isHerbal: QaInquiryDraft.isHerbalProduct(item.productKind),
      extras: [
        for (final extra in item.extras) _toCardItem(extra),
      ],
    );
  }

  void _onNext() {
    final selected = _selectedParents();
    if (selected.isEmpty) return;
    final item = selected.first;
    final odId = (item.odId ?? '').trim();
    final selectedByOrderNumber = _isOrderTab && odId.isNotEmpty;
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
        selectedByOrderNumber: selectedByOrderNumber,
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

  String get _emptyText => '선택 가능한 상품이 없습니다.';

  String get _emptyIcon {
    switch (_currentTab) {
      case QaItemSelectTab.order:
        return AppAssets.emptyOrderDeliveryIcon;
      case QaItemSelectTab.cancel:
        return AppAssets.emptyReturnIcon;
      case QaItemSelectTab.cart:
        return AppAssets.qaSelectCartIcon;
      case QaItemSelectTab.wish:
        return AppAssets.qaSelectWishlistIcon;
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
      appBar: HealthAppBar(
        title: '1:1 문의',
        leadingIconSize: healthDp(context, 16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
        children: [
          _buildTabs(context),
          Expanded(child: _buildBody(context)),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 20),
                healthDp(context, 8),
                healthDp(context, 20),
                healthDp(context, 20),
              ),
              child: GestureDetector(
                onTap: _selectedKeys.isEmpty ? null : _onNext,
                child: Container(
                  width: double.infinity,
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _selectedKeys.isEmpty
                        ? const Color(0xFFD2D2D2)
                        : _pink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
          if (!_loading &&
              (_error != null ||
                  (_isOrderTab ? _orderGroups.isEmpty : _items.isEmpty)))
            PageCenteredEmptyOverlay(child: _buildSelectEmpty(context)),
        ],
      ),
    );
  }

  Widget _buildSelectEmpty(BuildContext context) {
    final login = _error == '로그인이 필요합니다.';
    final message = _error != null
        ? (login ? '로그인 후 이용 가능합니다.' : '선택할 상품이 없습니다.')
        : _emptyText;
    final icon = _error != null ? AppAssets.emptyCategoryIcon : _emptyIcon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          icon,
          width: healthDp(context, 80),
          height: healthDp(context, 80),
          fit: BoxFit.contain,
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          message,
          style: TextStyle(
            color: const Color(0xFFC0C0C0),
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 20),
        healthDp(context, 20),
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabLabels.length; i++)
            _tabCell(
              context,
              index: i,
              expand: i != 1,
            ),
        ],
      ),
    );
  }

  Widget _tabCell(
    BuildContext context, {
    required int index,
    required bool expand,
  }) {
    final selected = _tabIndex == index;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_tabIndex == index) return;
        setState(() => _tabIndex = index);
        _load();
      },
      child: Container(
        padding: EdgeInsets.only(
          left: expand ? 0 : healthDp(context, 10),
          right: expand ? 0 : healthDp(context, 10),
          bottom: healthDp(context, 10),
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: healthDp(context, 1),
              color: selected
                  ? const Color(0xFFFF5A8D)
                  : const Color(0xFFD2D2D2),
            ),
          ),
        ),
        child: Text(
          _tabLabels[index],
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF5A8D)
                : const Color(0xFF898686),
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
    if (!expand) return child;
    return Expanded(child: child);
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _pink));
    }
    final hasItems = _error == null &&
        (_isOrderTab ? _orderGroups.isNotEmpty : _items.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 20),
            healthDp(context, 20),
            healthDp(context, 20),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문의하실 상품을 선택해주세요.',
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: healthSp(context, 18),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: healthDp(context, 8)),
              Text(
                _headerSub,
                style: TextStyle(
                  color: const Color(0xFF898686),
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        if (!hasItems)
          const Expanded(child: SizedBox.shrink())
        else
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(top: healthDp(context, 20)),
              children: [
                if (_isOrderTab)
                  for (final group in _orderGroups) _buildOrderGroup(group)
                else
                  ..._productRows(_items),
              ],
            ),
          ),
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
        ..._productRows(group.products),
      ],
    );
  }

  List<Widget> _productRows(List<_SelectableItem> items) {
    final makers = <String>[];
    for (final item in items) {
      final maker = (item.brandName ?? '').trim();
      if (maker.isEmpty || makers.contains(maker)) continue;
      makers.add(maker);
    }
    if (makers.length < 2) {
      return [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) _rowDivider(context),
          _buildProductRow(items[i]),
        ],
      ];
    }

    final order = <String>[];
    final map = <String, List<_SelectableItem>>{};
    for (final item in items) {
      final key = (item.brandName ?? '').trim();
      if (!map.containsKey(key)) {
        order.add(key);
        map[key] = [];
      }
      map[key]!.add(item);
    }

    final rows = <Widget>[];
    for (final key in order) {
      if (key.isNotEmpty) {
        rows.add(QaManufacturerBar(name: key));
      }
      for (final item in map[key]!) {
        if (rows.isNotEmpty && rows.last is! QaManufacturerBar) {
          rows.add(_rowDivider(context));
        }
        rows.add(_buildProductRow(item));
      }
    }
    return rows;
  }

  Widget _rowDivider(BuildContext context) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 1),
      color: const Color(0x7FD2D2D2),
    );
  }

  Widget _buildProductRow(_SelectableItem item) {
    final extraInset = healthDp(context, 24);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 10),
        healthDp(context, 20),
        healthDp(context, 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductSelectRow(
            item: item,
            selected: _selectedKeys.contains(item.key),
            showOptions:
                item.showOptions && _currentTab != QaItemSelectTab.wish,
            embedded: true,
            onTap: () => _toggleItem(item),
          ),
          if (item.extras.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            Padding(
              padding: EdgeInsets.only(left: extraInset),
              child: _ExtraDropdown(extras: item.extras),
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

  _SelectableItem withMaker(
    String? maker, {
    List<_SelectableItem>? extras,
  }) {
    return _SelectableItem(
      key: key,
      itId: itId,
      productKind: productKind,
      productName: productName,
      brandName: (maker ?? '').trim().isNotEmpty ? maker : brandName,
      imageUrl: imageUrl,
      price: price,
      odId: odId,
      orderDate: orderDate,
      qty: qty,
      optionParts: optionParts,
      itSubject: itSubject,
      parentItId: parentItId,
      fromCart: fromCart,
      showOptions: showOptions,
      extras: extras ?? this.extras,
    );
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
            color: selected ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
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
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 20),
          vertical: healthDp(context, 10),
        ),
        color: const Color(0xFFFCFCFB),
        child: Row(
          children: [
            _CheckBox(selected: selected),
            SizedBox(width: healthDp(context, 4)),
            Text(
              '주문번호',
              style: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 14),
                fontFamily: _font,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(width: healthDp(context, 4)),
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
    final thumb = healthDp(context, 72);
    final parts = showOptions
        ? (item.optionParts.isNotEmpty ? item.optionParts : ['수량: ${item.qty}'])
        : const <String>[];

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: embedded
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(
                horizontal: healthDp(context, compact ? 0 : 20),
                vertical: healthDp(context, 10),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckBox(selected: selected),
            SizedBox(width: healthDp(context, 4)),
            ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
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
            SizedBox(width: healthDp(context, 10)),
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
                      letterSpacing: healthSp(context, -0.56),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parts.isNotEmpty) ...[
                    SizedBox(height: healthDp(context, 4)),
                    _OptionMetaRow(parts: parts),
                  ],
                  Padding(
                    padding: EdgeInsets.only(top: healthDp(context, 8)),
                    child: Text(
                      '${PriceFormatter.format(item.price)}원',
                      style: TextStyle(
                        color: _ink,
                        fontSize: healthSp(context, 14),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
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
      spacing: healthDp(context, 4),
      runSpacing: healthDp(context, 4),
      children: [
        for (var i = 0; i < parts.length; i++)
          Text(
            parts[i],
            style: TextStyle(
              color: i == parts.length - 1 && parts.length > 1
                  ? const Color(0xFF898686)
                  : const Color(0xFF898383),
              fontSize: healthSp(context, 10),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              letterSpacing: healthSp(context, -0.90),
            ),
          ),
      ],
    );
  }
}

class _ExtraDropdown extends StatelessWidget {
  const _ExtraDropdown({
    required this.extras,
  });

  final List<_SelectableItem> extras;

  String _optionLine(_SelectableItem extra) {
    final opts = extra.optionParts.where((e) => !e.startsWith('수량:')).toList();
    if (opts.isEmpty) return extra.qty > 0 ? '수량: ${extra.qty}' : '';
    return opts.join(' ㅣ ');
  }

  @override
  Widget build(BuildContext context) {
    return SupplyAddExpandBlock(
      count: extras.length,
      children: [
        for (var i = 0; i < extras.length; i++)
          SupplyAddReadOnlyRow(
            name: extras[i].productName,
            optionLine: _optionLine(extras[i]),
            price: extras[i].price,
            imageUrl: extras[i].imageUrl,
            showDivider: i < extras.length - 1,
            thumbBase: 48,
            nameFontBase: 12,
            optionFontBase: 10,
            priceFontBase: 12,
            nameLetterSpacingBase: -0.48,
            optionLetterSpacingBase: -0.60,
          ),
      ],
    );
  }
}
