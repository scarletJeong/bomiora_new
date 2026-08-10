import 'package:flutter/material.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/scroll_reveal_top_overlay.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/utils/price_formatter.dart';
import 'payment_screen.dart';
import '../widgets/cart_add_group_card.dart';
import '../widgets/cart_group_general_card.dart';

class CartScreen extends StatefulWidget {
  final String? backToProductId;
  final int initialTabIndex;

  /// true면 Scaffold/AppBar 없이 본문만 (통합 장바구니 탭용)
  final bool embedInParent;

  /// 통합 장바구니 탭 헤더 (스크롤과 함께 이동)
  final Widget? scrollHeader;

  const CartScreen({
    super.key,
    this.backToProductId,
    this.initialTabIndex = 0,
    this.embedInParent = false,
    this.scrollHeader,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> cartItems = [];
  bool isLoading = true;
  bool isRefreshing = false; // 새로고침 중인지 (캐시된 데이터 표시 중)
  String? errorMessage;
  int shippingCost = 0; // 배송비
  int totalPrice = 0; // 총구매금액
  Set<int> selectedItems = {}; // 선택된 아이템의 ctId 집합
  bool selectAll = false; // 현재 탭의 전체 선택 상태
  final ScrollController _scrollController = ScrollController();

  List<CartLineGroup> get _displayedGroups =>
      cartGroupsForTab(cartItems, prescriptionTab: false);

  List<CartItem> get _displayedCartItems {
    return _displayedGroups.expand((g) => g.allItems).toList();
  }

  Set<int> get _displayedItemIds {
    return _displayedCartItems.map((item) => item.ctId).toSet();
  }

  Set<int> get _selectedDisplayedItemIds {
    return selectedItems.intersection(_displayedItemIds);
  }

  static const String _selectionCtKind = 'general';

  void _applySelectionFromServer() {
    selectedItems = _displayedCartItems
        .where((item) => item.ctSelect)
        .map((item) => item.ctId)
        .toSet();
    selectAll = _displayedCartItems.isNotEmpty &&
        _displayedItemIds.difference(selectedItems).isEmpty;
  }

  Future<void> _persistCartSelection() async {
    final result = await CartService.syncCartSelection(
      selectedCtIds: _selectedDisplayedItemIds.toList(),
      ctKind: _selectionCtKind,
    );
    if (!mounted || result['success'] == true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? '선택 저장에 실패했습니다.',
        ),
      ),
    );
  }

  List<CartItem> _preserveCartItemOrder(
    List<CartItem> previous,
    List<CartItem> incoming,
  ) {
    if (previous.isEmpty) return incoming;

    final incomingById = <int, CartItem>{
      for (final item in incoming) item.ctId: item,
    };

    final ordered = <CartItem>[];
    for (final item in previous) {
      final updated = incomingById.remove(item.ctId);
      if (updated != null) {
        ordered.add(updated);
      }
    }
    ordered.addAll(incomingById.values);
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLoggedIn({
    String message = '로그인 후 이용할 수 있습니다.',
  }) async {
    final user = await AuthService.getUser();
    if (user != null && user.id.isNotEmpty) return true;
    if (!mounted) return false;
    await showLoginRequiredDialog(context, message: message);
    return false;
  }

  Future<void> _loadCart({bool showCachedData = false}) async {
    // 캐시된 데이터를 먼저 표시하고 백그라운드에서 갱신하는 모드
    final hasCachedData = showCachedData && cartItems.isNotEmpty;

    if (!hasCachedData) {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    } else {
      if (!mounted) return;
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      final previousItems = List<CartItem>.from(cartItems);
      final result = await CartService.getCart();
      if (!mounted) return;

      if (result['success'] == true) {
        // null 체크 추가 (웹 환경 대응)
        final data = result['data'];
        final items = (data is List ? data : [])
            .map((item) {
              try {
                return CartItem.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                return null;
              }
            })
            .whereType<CartItem>() // null 제거
            .toList();
        final orderedItems = _preserveCartItemOrder(previousItems, items);
        setState(() {
          cartItems = orderedItems;
          shippingCost = (result['shipping_cost'] as int?) ?? 0;
          totalPrice = (result['total_price'] as int?) ?? 0;
          _applySelectionFromServer();

          isLoading = false;
          isRefreshing = false;
        });
      } else {
        final message = result['message']?.toString() ?? '';
        setState(() {
          if (!hasCachedData) {
            if (message.contains('로그인')) {
              cartItems = [];
              shippingCost = 0;
              totalPrice = 0;
              errorMessage = null;
            } else {
              errorMessage =
                  message.isNotEmpty ? message : '장바구니를 불러오는데 실패했습니다.';
            }
            isLoading = false;
          } else {
            // 캐시된 데이터를 유지하고 에러 무시
            isRefreshing = false;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!hasCachedData) {
          errorMessage = '장바구니를 불러오는 중 오류가 발생했습니다: $e';
          isLoading = false;
        } else {
          // 캐시된 데이터를 유지하고 에러 무시
          isRefreshing = false;
        }
      });
    }
  }

  Future<void> _updateQuantity(int ctId, int newQuantity) async {
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    if (newQuantity < 1) return;

    final result = await CartService.updateCartQuantity(
      ctId: ctId,
      quantity: newQuantity,
    );

    if (!mounted || result['success'] != true) return;

    setState(() {
      final index = cartItems.indexWhere((item) => item.ctId == ctId);
      if (index < 0) return;

      final data = result['data'];
      if (data is Map) {
        cartItems[index] =
            CartItem.fromJson(Map<String, dynamic>.from(data));
      } else {
        final old = cartItems[index];
        final unitPrice =
            old.ctQty > 0 ? old.ctPrice / old.ctQty : old.ctPrice.toDouble();
        cartItems[index] = CartItem(
          ctId: old.ctId,
          odId: old.odId,
          mbId: old.mbId,
          itId: old.itId,
          itName: old.itName,
          itSubject: old.itSubject,
          ctStatus: old.ctStatus,
          ctPrice: (unitPrice * newQuantity).round(),
          ctOption: old.ctOption,
          ctQty: newQuantity,
          ioId: old.ioId,
          ioPrice: old.ioPrice,
          ctKind: old.ctKind,
          ctTime: old.ctTime,
          doctorName: old.doctorName,
          reservationDate: old.reservationDate,
          reservationTime: old.reservationTime,
          imageUrl: old.imageUrl,
          productType: old.productType,
          ctMbInf: old.ctMbInf,
          pointUsageRate: old.pointUsageRate,
          ctSelect: old.ctSelect,
        );
      }

      totalPrice = cartItems.fold<int>(0, (sum, item) => sum + item.lineAmount);
    });
  }

  Future<void> _deleteCartItem(int ctId) async {
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: '삭제 확인',
      message: '장바구니에서 이 상품을\n삭제하시겠습니까?',
      cancelText: '취소',
      confirmText: '삭제',
    );

    if (confirmed) {
      final result = await CartService.removeCartItem(ctId);
      if (!mounted) return;

      if (result['success'] == true) {
        // 선택된 아이템에서도 제거
        setState(() {
          selectedItems.remove(ctId);
        });
        AppToastOverlay.show(context, '장바구니에서 상품이 삭제됐어요.');
        _loadCart(showCachedData: true); // 장바구니 다시 로드 (캐시 표시)
      }
    }
  }

  // 선택된 아이템들 삭제
  Future<void> _deleteSelectedItems() async {
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    final selectedDisplayedItems = _selectedDisplayedItemIds;
    if (selectedDisplayedItems.isEmpty) return;

    final itemsToDelete = List<int>.from(selectedDisplayedItems);
    for (final ctId in itemsToDelete) {
      await CartService.removeCartItem(ctId);
    }

    if (!mounted) return;

    AppToastOverlay.show(context, '장바구니에서 상품이 삭제됐어요.');

    setState(() {
      selectedItems.removeAll(itemsToDelete);
      selectAll = false;
    });

    await _persistCartSelection();
    _loadCart(showCachedData: true);
  }

  // 선택된 아이템들의 총구매금액 계산
  int get selectedTotalPrice {
    int sum = 0;
    for (var item in _displayedCartItems) {
      if (selectedItems.contains(item.ctId)) {
        sum += item.lineAmount;
      }
    }
    return sum;
  }

  // 선택된 아이템의 배송비 계산 (현재는 간단히 전체 배송비를 사용)
  // TODO: 선택된 아이템만으로 배송비를 계산하도록 백엔드 API 수정 필요
  int get selectedShippingCost {
    // 현재 탭에서 선택된 아이템이 없으면 배송비 0
    if (_selectedDisplayedItemIds.isEmpty) return 0;
    // 처방/일반이 혼합된 장바구니에서는 탭별 배송비를 백엔드가 내려주지 않으므로
    // 다른 탭 금액이 섞여 보이지 않게 0으로 처리한다.
    if (_displayedCartItems.length != cartItems.length) return 0;
    // 선택된 아이템이 현재 탭 전체와 같으면 전체 배송비 사용
    if (_selectedDisplayedItemIds.length == _displayedCartItems.length) {
      return shippingCost;
    }
    // 일부만 선택한 경우도 전체 배송비를 사용 (추후 백엔드에서 재계산 필요)
    return shippingCost;
  }

  int get finalPrice => selectedTotalPrice + selectedShippingCost;

  Future<void> _openPaymentScreen() async {
    if (!await _ensureLoggedIn(message: '상품 구매는 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    if (_selectedDisplayedItemIds.isEmpty) return;

    final selectedCartItems = _displayedCartItems
        .where((item) => _selectedDisplayedItemIds.contains(item.ctId))
        .toList();
    if (selectedCartItems.isEmpty) return;

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/pay'),
        builder: (context) => PaymentScreen(
          cartItems: selectedCartItems,
          shippingCost: selectedShippingCost,
          sourceTitle: '일반상품 장바구니',
        ),
      ),
    );

    if (!mounted) return;
    if (paid == true) {
      await _loadCart(showCachedData: false);
    }
  }

  void _handleBackNavigation() {
    final backToProductId = widget.backToProductId;
    if (backToProductId != null && backToProductId.isNotEmpty) {
      Navigator.of(context)
          .pushReplacementNamed('/product-general/$backToProductId');
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Widget _wrapWithOptionalHeader(Widget body) {
    final header = widget.scrollHeader;
    if (header == null) return body;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverFillRemaining(
          hasScrollBody: false,
          child: body,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return _wrapWithOptionalHeader(
        const Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return _wrapWithOptionalHeader(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
              SizedBox(height: healthDp(context, 16)),
              ElevatedButton(
                onPressed: _loadCart,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (_displayedCartItems.isEmpty) {
      return _wrapWithOptionalHeader(
        const CenteredEmptyState(
          icon: Icons.shopping_cart_outlined,
          message: '장바구니가 비어있습니다.',
        ),
      );
    }
    return Column(
                    children: [
                      Expanded(
                        child: ScrollRevealTopOverlay(
                          controller: _scrollController,
                          revealAfterOffset: healthDp(context, 44),
                          barPadding: EdgeInsets.fromLTRB(
                            healthDp(context, 27),
                            healthDp(context, 8),
                            healthDp(context, 27),
                            0,
                          ),
                          topBar: _buildSelectAllRow(),
                          scrollChild: RefreshIndicator(
                            onRefresh: () => _loadCart(showCachedData: false),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(
                                bottom: healthDp(context, 16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      healthDp(context, 27),
                                      widget.scrollHeader != null
                                          ? 0
                                          : healthDp(context, 16),
                                      healthDp(context, 27),
                                      healthDp(context, 16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (widget.scrollHeader != null) ...[
                                          widget.scrollHeader!,
                                          SizedBox(height: healthDp(context, 8)),
                                        ],
                                        _buildSelectAllRow(),
                                        SizedBox(height: healthDp(context, 12)),
                                        ...groupCartByVendor(_displayedGroups)
                                            .expand(
                                          (entry) => [
                                            CartGroupGeneralCard(
                                              vendorName: entry.key,
                                              groups: entry.value,
                                              selectedItems: selectedItems,
                                              buildCheckbox: ({
                                                required value,
                                                required onChanged,
                                              }) =>
                                                  _lightCheckbox(
                                                value: value,
                                                onChanged: onChanged,
                                              ),
                                              buildQtyControl: ({
                                                required quantity,
                                                required onDecrease,
                                                required onIncrease,
                                              }) =>
                                                  _buildFigmaQtyControl(
                                                quantity: quantity,
                                                onDecrease: onDecrease,
                                                onIncrease: onIncrease,
                                              ),
                                              onToggleVendor: (selected) {
                                                setState(() {
                                                  final ids = entry.value
                                                      .expand((g) => g.allItems)
                                                      .map((e) => e.ctId);
                                                  if (selected) {
                                                    selectedItems.addAll(ids);
                                                  } else {
                                                    selectedItems
                                                        .removeAll(ids);
                                                  }
                                                  selectAll =
                                                      _displayedCartItems
                                                              .isNotEmpty &&
                                                          _displayedItemIds
                                                              .difference(
                                                                  selectedItems)
                                                              .isEmpty;
                                                });
                                                _persistCartSelection();
                                              },
                                              onToggleItem: (item, selected) {
                                                setState(() {
                                                  if (selected) {
                                                    selectedItems.add(item.ctId);
                                                    for (final g
                                                        in _displayedGroups) {
                                                      if (g.parent.ctId ==
                                                          item.ctId) {
                                                        for (final c
                                                            in g.children) {
                                                          selectedItems
                                                              .add(c.ctId);
                                                        }
                                                      }
                                                    }
                                                  } else {
                                                    selectedItems
                                                        .remove(item.ctId);
                                                    for (final g
                                                        in _displayedGroups) {
                                                      if (g.parent.ctId ==
                                                          item.ctId) {
                                                        for (final c
                                                            in g.children) {
                                                          selectedItems
                                                              .remove(c.ctId);
                                                        }
                                                      }
                                                    }
                                                  }
                                                  selectAll =
                                                      _displayedCartItems
                                                              .isNotEmpty &&
                                                          _displayedItemIds
                                                              .difference(
                                                                  selectedItems)
                                                              .isEmpty;
                                                });
                                                _persistCartSelection();
                                              },
                                              onQuantityChanged: (item, qty) =>
                                                  _updateQuantity(
                                                      item.ctId, qty),
                                              onDelete: (item) =>
                                                  _deleteCartItem(item.ctId),
                                              onOpenDetail: (item) =>
                                                  _openGeneralProductDetail(
                                                      item.itId),
                                            ),
                                            SizedBox(
                                                height: healthDp(context, 12)),
                                          ],
                                        ),
                                        if (_displayedCartItems.isEmpty)
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: healthDp(context, 40)),
                                            child: Text(
                                              '선택한 탭에 상품이 없습니다.',
                                              style: TextStyle(
                                                fontSize: healthSp(context, 14),
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        SizedBox(height: healthDp(context, 18)),
                                        _buildScrollablePriceSummary(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildCheckoutBar(),
                    ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (widget.embedInParent) {
      return ColoredBox(color: Colors.white, child: body);
    }
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '일반상품 장바구니',
          centerTitle: false,
          onBack: _handleBackNavigation,
          actions: const [],
        ),
        body: body,
      ),
    );
  }

  Widget _buildScrollablePriceSummary() {
    final selectedPrice = selectedTotalPrice;
    final selectedShipping = selectedShippingCost;
    final payable = finalPrice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryRow('구매금액', '${PriceFormatter.format(selectedPrice)}원',
            fontSize: healthSp(context, 16), fontWeight: FontWeight.w500),
        SizedBox(height: healthDp(context, 10)),
        _summaryRow('배송비', '${PriceFormatter.format(selectedShipping)}원',
            fontSize: healthSp(context, 14), fontWeight: FontWeight.w500),
        SizedBox(height: healthDp(context, 10)),
        Divider(
          height: healthDp(context, 1),
          thickness: healthDp(context, 1),
          color: const Color(0x7F1A1A1A),
        ),
        SizedBox(height: healthDp(context, 10)),
        _summaryRow('결제 금액', '${PriceFormatter.format(payable)}원',
            fontSize: healthSp(context, 16), fontWeight: FontWeight.w700),
      ],
    );
  }

  Widget _buildCheckoutBar() {
    final selected = _selectedDisplayedItemIds;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 8),
        healthDp(context, 27),
        healthDp(context, 8) + bottomInset.clamp(0, healthDp(context, 10)),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: healthDp(context, 8),
            offset: Offset(0, -healthDp(context, 2)),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: healthDp(context, 40),
        child: ElevatedButton(
          onPressed: selected.isEmpty ? null : _openPaymentScreen,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, healthDp(context, 40)),
            maximumSize: Size(double.infinity, healthDp(context, 40)),
            padding: EdgeInsets.zero,
            backgroundColor: const Color(0xFFFF5A8D),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Text(
            '결제하기',
            style: TextStyle(
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectAllRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: healthDp(context, 8)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: healthDp(context, 1),
          ),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _lightCheckbox(
                value: _displayedCartItems.isNotEmpty &&
                    _displayedItemIds.difference(selectedItems).isEmpty,
                onChanged: (bool? value) {
                  setState(() {
                    final shouldSelect = value ?? false;
                    if (shouldSelect) {
                      selectedItems.addAll(_displayedItemIds);
                    } else {
                      selectedItems.removeAll(_displayedItemIds);
                    }
                    selectAll = _displayedCartItems.isNotEmpty &&
                        _displayedItemIds.difference(selectedItems).isEmpty;
                  });
                  _persistCartSelection();
                },
              ),
              SizedBox(width: healthDp(context, 4)),
              Text(
                '전체선택',
                style: TextStyle(
                  fontSize: healthSp(context, 13),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _selectedDisplayedItemIds.isEmpty
                    ? null
                    : () => _deleteSelectedItems(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 8),
                      vertical: healthDp(context, 4)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '선택삭제',
                  style: TextStyle(
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lightCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    const double checkboxBase = 18;
    final boxSize = healthDp(context, checkboxBase);
    final scale = boxSize / checkboxBase;
    const borderColor = Color(0xFFD2D2D2);
    const checkPink = Color(0xFFFF5A8D);

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Theme(
            data: Theme.of(context).copyWith(
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.all(Colors.white),
                checkColor: WidgetStateProperty.all(checkPink),
                side: const BorderSide(color: borderColor, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 4)),
                ),
              ),
            ),
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              fillColor: WidgetStateProperty.all(Colors.white),
              checkColor: checkPink,
              side: WidgetStateBorderSide.resolveWith(
                (_) => const BorderSide(color: borderColor, width: 1),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(
    String left,
    String right, {
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: fontWeight,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  void _openGeneralProductDetail(String productId) {
    Navigator.pushNamed(context, '/product-general/$productId');
  }

  Widget _buildFigmaQtyControl({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Container(
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFigmaQtyButton(icon: Icons.remove, onTap: onDecrease),
          SizedBox(
            width: healthDp(context, 18),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 12),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                height: 0.79,
              ),
            ),
          ),
          _buildFigmaQtyButton(icon: Icons.add, onTap: onIncrease),
        ],
      ),
    );
  }

  Widget _buildFigmaQtyButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Container(
        width: healthDp(context, 20),
        height: healthDp(context, 20),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x0C000000),
              blurRadius: healthDp(context, 1.07),
              offset: Offset(0, healthDp(context, 0.54)),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: healthDp(context, 14),
          color: onTap == null ? Colors.grey[300] : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }

  // 탭 UI 제거: 처방상품 장바구니 단일 화면
}

