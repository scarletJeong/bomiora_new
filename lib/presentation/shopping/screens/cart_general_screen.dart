import 'dart:async';

import 'package:flutter/material.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/load_failure_notice.dart';
import '../../common/widgets/scroll_reveal_top_overlay.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../../core/logging/failure_log.dart';
import '../../../data/services/cart_price_watch.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/utils/price_formatter.dart';
import 'payment_screen.dart';
import '../widgets/cart_add_group_card.dart';
import '../widgets/cart_empty_shop_button.dart';
import '../widgets/cart_price_changed_dialog.dart';
import '../widgets/cart_group_general_card.dart';
import '../widgets/quantity_stepper.dart';

class CartScreen extends StatefulWidget {
  final String? backToProductId;
  final int initialTabIndex;

  /// true면 Scaffold/AppBar 없이 본문만 (통합 장바구니 탭용)
  final bool embedInParent;

  /// 통합 장바구니 탭 헤더 (스크롤과 함께 이동)
  final Widget? scrollHeader;

  /// 이 탭에 담긴 줄 수(본품+추가상품)가 바뀔 때
  final ValueChanged<int>? onDisplayedCount;

  const CartScreen({
    super.key,
    this.backToProductId,
    this.initialTabIndex = 0,
    this.embedInParent = false,
    this.scrollHeader,
    this.onDisplayedCount,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> cartItems = [];
  bool isLoading = true;
  bool isRefreshing = false; // 새로고침 중인지 (캐시된 데이터 표시 중)
  bool needsLogin = false;
  String? errorMessage;
  int shippingCost = 0; // 배송비
  int _selectedShippingCost = 0;
  int totalPrice = 0; // 총구매금액
  Set<int> selectedItems = {}; // 선택된 아이템의 ctId 집합
  bool selectAll = false; // 현재 탭의 전체 선택 상태
  bool _checkoutOpening = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _shippingDebounce;
  Future<void>? _pendingQtyUpdate;
  final Map<int, int> _qtyEpochById = {};
  bool _deleteBusy = false;
  int _lastDisplayedCount = -1;
  bool _countNotifyScheduled = false;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleDisplayedCount();
  }

  void _scheduleDisplayedCount() {
    if (widget.onDisplayedCount == null || _countNotifyScheduled) return;
    if (isLoading && cartItems.isEmpty) return;
    _countNotifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _countNotifyScheduled = false;
      if (!mounted) return;
      final count = _displayedCartItems.length;
      if (count == _lastDisplayedCount) return;
      _lastDisplayedCount = count;
      widget.onDisplayedCount?.call(count);
    });
  }

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

  Set<int> get _availableDisplayedItemIds {
    return _displayedCartItems
        .where((item) => item.isAvailable)
        .map((item) => item.ctId)
        .toSet();
  }

  bool get _hasSoldOutItems =>
      _displayedCartItems.any((item) => !item.isAvailable);

  static const String _selectionCtKind = 'general';

  void _applySelectionFromServer() {
    selectedItems = _displayedCartItems
        .where((item) => item.ctSelect && item.isAvailable)
        .map((item) => item.ctId)
        .toSet();
    final available = _availableDisplayedItemIds;
    selectAll =
        available.isNotEmpty && available.difference(selectedItems).isEmpty;
  }

  void _scheduleShippingRefresh() {
    _shippingDebounce?.cancel();
    _shippingDebounce = Timer(const Duration(milliseconds: 250), () {
      _refreshSelectedShipping();
    });
  }

  Future<void> _refreshSelectedShipping() async {
    final ids = _displayedCartItems
        .where((item) => selectedItems.contains(item.ctId) && item.isAvailable)
        .map((item) => item.ctId)
        .toList();
    final cost =
        ids.isEmpty ? 0 : await CartService.getShippingCost(ctIds: ids);
    if (!mounted) return;
    setState(() => _selectedShippingCost = cost);
  }

  Future<void> _persistCartSelection() async {
    _scheduleShippingRefresh();
    final result = await CartService.syncCartSelection(
      selectedCtIds: _selectedDisplayedItemIds
          .where((id) => _availableDisplayedItemIds.contains(id))
          .toList(),
      ctKind: _selectionCtKind,
    );
    if (!mounted || result['success'] == true) return;
    AppToastOverlay.show(
      context,
      result['message']?.toString() ?? '선택 저장에 실패했습니다.',
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
    AuthService.sessionTick.addListener(_onSessionTick);
    _loadCart(forceRefresh: true);
  }

  @override
  void dispose() {
    AuthService.sessionTick.removeListener(_onSessionTick);
    _shippingDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSessionTick() {
    _loadCart(forceRefresh: true);
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

  Future<void> _recordCartLoadFailure(String reason) async {
    final user = await AuthService.getUser();
    await FailureLog.record(
      code: 'cart.list',
      mbId: user?.id ?? '',
      reason: reason,
      detail: const {'kind': 'general'},
    );
  }

  Future<void> _applyCartLoadFailure(String reason) async {
    await _recordCartLoadFailure(reason);
    if (!mounted) return;
    final keepItems = cartItems.isNotEmpty;
    setState(() {
      isLoading = false;
      isRefreshing = false;
      needsLogin = false;
      errorMessage = keepItems ? null : '장바구니를 불러오지 못했습니다.';
    });
    if (keepItems) {
      AppToastOverlay.showAlert(context, '장바구니를 불러오지 못했습니다.');
    }
  }

  void _showLoginRequiredCart() {
    setState(() {
      cartItems = [];
      shippingCost = 0;
      totalPrice = 0;
      selectedItems = {};
      selectAll = false;
      needsLogin = true;
      errorMessage = null;
      isLoading = false;
      isRefreshing = false;
    });
  }

  Future<bool> _loadCart({
    bool showCachedData = false,
    bool forceRefresh = false,
  }) async {
    final keepVisible = showCachedData && cartItems.isNotEmpty;

    if (!keepVisible) {
      if (!mounted) return false;
      setState(() {
        isLoading = true;
        errorMessage = null;
        needsLogin = false;
      });
    } else {
      if (!mounted) return false;
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      final previousItems = List<CartItem>.from(cartItems);
      final result = await CartService.getCart(forceRefresh: forceRefresh);
      if (!mounted) return false;

      final message = result['message']?.toString() ?? '';
      if (result['needsLogin'] == true) {
        _showLoginRequiredCart();
        return false;
      }

      if (result['success'] == true) {
        final items = CartService.parseCartItems(result['data']);
        final orderedItems = _preserveCartItemOrder(previousItems, items);
        final priceChanged = await CartPriceWatch.consumeChanges(orderedItems);
        if (!mounted) return false;
        setState(() {
          cartItems = orderedItems;
          shippingCost = (result['shipping_cost'] as int?) ?? 0;
          totalPrice = (result['total_price'] as int?) ?? 0;
          _applySelectionFromServer();
          needsLogin = false;
          errorMessage = null;
          isLoading = false;
          isRefreshing = false;
        });
        unawaited(_refreshSelectedShipping());
        if (priceChanged && mounted) {
          await showCartPriceChangedDialog(context);
        }
        return priceChanged;
      }

      await _applyCartLoadFailure(
        message.isNotEmpty ? message : '장바구니를 불러오지 못했습니다.',
      );
    } catch (e) {
      if (!mounted) return false;
      await _applyCartLoadFailure(e.toString());
    }
    return false;
  }

  CartItem _itemWithQuantity(CartItem old, int quantity) {
    // ct_price는 단가 — 수량만 바꾸고 단가는 유지 (PHP와 동일)
    return CartItem(
      ctId: old.ctId,
      odId: old.odId,
      mbId: old.mbId,
      itId: old.itId,
      itName: old.itName,
      itSubject: old.itSubject,
      ctStatus: old.ctStatus,
      ctPrice: old.ctPrice,
      ctOption: old.ctOption,
      ctQty: quantity,
      ioId: old.ioId,
      ioPrice: old.ioPrice,
      ioType: old.ioType,
      ctKind: old.ctKind,
      kind: old.kind,
      itKind: old.itKind,
      parentItId: old.parentItId,
      itSupplyItems: old.itSupplyItems,
      ctTime: old.ctTime,
      doctorName: old.doctorName,
      reservationDate: old.reservationDate,
      reservationTime: old.reservationTime,
      imageUrl: old.imageUrl,
      productType: old.productType,
      caId: old.caId,
      caId2: old.caId2,
      caId3: old.caId3,
      ctMbInf: old.ctMbInf,
      pointUsageRate: old.pointUsageRate,
      ctSelect: old.ctSelect,
      isAvailable: old.isAvailable,
      unavailableReason: old.unavailableReason,
    );
  }

  Future<void> _updateQuantity(int ctId, int newQuantity) async {
    if (newQuantity < 1) return;
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    if (!mounted) return;

    final index = cartItems.indexWhere((item) => item.ctId == ctId);
    if (index < 0) return;
    final previous = cartItems[index];
    if (previous.ctQty == newQuantity) return;

    final epoch = (_qtyEpochById[ctId] ?? 0) + 1;
    _qtyEpochById[ctId] = epoch;
    setState(() {
      cartItems[index] = _itemWithQuantity(previous, newQuantity);
      totalPrice = cartItems.fold<int>(0, (sum, item) => sum + item.lineAmount);
    });

    final resultFuture = CartService.updateCartQuantity(
      ctId: ctId,
      quantity: newQuantity,
    );
    _pendingQtyUpdate = resultFuture.then((_) {});
    final result = await resultFuture;
    if (!mounted || _qtyEpochById[ctId] != epoch) return;

    if (result['success'] == true) {
      _scheduleShippingRefresh();
      return;
    }

    setState(() {
      final current = cartItems.indexWhere((item) => item.ctId == ctId);
      if (current >= 0) cartItems[current] = previous;
      totalPrice = cartItems.fold<int>(0, (sum, item) => sum + item.lineAmount);
    });
    AppToastOverlay.show(
      context,
      result['message']?.toString() ?? '수량 변경에 실패했습니다.',
    );
  }

  /// 본품을 지우면 같은 상품의 추가상품 줄도 같이 뺀다.
  Set<int> _expandDeleteIds(Iterable<int> ctIds) {
    final ids = ctIds.where((id) => id > 0).toSet();
    final parents = cartItems
        .where((item) => ids.contains(item.ctId) && !item.isSupplyAdd)
        .map((item) => item.itId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (parents.isEmpty) return ids;
    for (final item in cartItems) {
      final parent = (item.parentItId ?? '').trim();
      if (parent.isNotEmpty && parents.contains(parent)) {
        ids.add(item.ctId);
      }
    }
    return ids;
  }

  void _dropCartItems(Set<int> ids) {
    cartItems = cartItems.where((item) => !ids.contains(item.ctId)).toList();
    selectedItems.removeAll(ids);
    totalPrice = cartItems.fold<int>(0, (sum, item) => sum + item.lineAmount);
    final available = _availableDisplayedItemIds;
    selectAll =
        available.isNotEmpty && available.difference(selectedItems).isEmpty;
  }

  Future<void> _commitCartDelete(
    Set<int> ids,
    String successMessage, {
    bool canUndo = true,
  }) async {
    if (_deleteBusy || ids.isEmpty) return;
    final snapshotItems = List<CartItem>.from(cartItems);
    final snapshotSelected = Set<int>.from(selectedItems);
    final snapshotTotal = totalPrice;
    final snapshotSelectAll = selectAll;
    final removed =
        snapshotItems.where((item) => ids.contains(item.ctId)).toList();
    _deleteBusy = true;
    setState(() => _dropCartItems(ids));
    var deleteFinished = false;
    var undoAsked = false;
    Future<void> undo() async {
      if (undoAsked) return;
      undoAsked = true;
      if (!deleteFinished) return;
      await _restoreDeletedCartItems(removed);
    }

    AppToastOverlay.showCartDeleted(
      context,
      successMessage,
      onUndo: canUndo ? () { undo(); } : null,
    );
    _scheduleShippingRefresh();
    final result = await CartService.removeCartItems(ids.toList());
    deleteFinished = true;
    _deleteBusy = false;
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        cartItems = snapshotItems;
        selectedItems = snapshotSelected;
        totalPrice = snapshotTotal;
        selectAll = snapshotSelectAll;
      });
      _scheduleShippingRefresh();
      if (!undoAsked) {
        AppToastOverlay.show(
          context,
          result['message']?.toString() ?? '장바구니 삭제에 실패했습니다.',
        );
      }
      return;
    }
    if (undoAsked) {
      await _restoreDeletedCartItems(removed);
    }
  }

  Future<void> _restoreDeletedCartItems(List<CartItem> removed) async {
    final result = await CartService.restoreCartItems(removed);
    if (!mounted) return;
    if (result['success'] != true) {
      AppToastOverlay.show(
        context,
        result['message']?.toString() ?? '다시 담기에 실패했습니다.',
      );
      return;
    }
    await _loadCart(forceRefresh: true);
  }

  Future<void> _deleteCartItem(int ctId) async {
    if (_deleteBusy) return;
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
    if (confirmed != true || !mounted) return;
    await _commitCartDelete(
      _expandDeleteIds([ctId]),
      '장바구니에서 상품이 삭제되었습니다.',
    );
  }

  Future<void> _deleteSelectedItems() async {
    if (_deleteBusy) return;
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    final selectedDisplayedItems = _selectedDisplayedItemIds;
    if (selectedDisplayedItems.isEmpty) return;
    await _commitCartDelete(
      _expandDeleteIds(selectedDisplayedItems),
      '장바구니에서 상품이 삭제되었습니다.',
    );
  }

  Future<void> _deleteSoldOutItems() async {
    if (_deleteBusy) return;
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    final toDelete = <int>{};
    for (final g in _displayedGroups) {
      if (!g.parent.isAvailable) {
        toDelete.add(g.parent.ctId);
        toDelete.addAll(g.children.map((c) => c.ctId));
      } else {
        for (final c in g.children) {
          if (!c.isAvailable) toDelete.add(c.ctId);
        }
      }
    }
    if (toDelete.isEmpty) return;
    await _commitCartDelete(
      toDelete,
      '품절·판매중지 상품이 삭제되었습니다.',
      canUndo: false,
    );
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

  int get selectedShippingCost {
    if (_selectedDisplayedItemIds.isEmpty) return 0;
    return _selectedShippingCost;
  }

  int get finalPrice => selectedTotalPrice + selectedShippingCost;

  Future<void> _openPaymentScreen(Set<int> selectedIds) async {
    if (_checkoutOpening || selectedIds.isEmpty) return;
    _checkoutOpening = true;
    setState(() {});

    final hasPayableItem = _displayedCartItems.any(
      (item) => selectedIds.contains(item.ctId) && item.isAvailable,
    );
    if (!hasPayableItem) {
      AppToastOverlay.show(context, '판매 가능한 상품을 선택해 주세요.');
      if (mounted) setState(() => _checkoutOpening = false);
      return;
    }

    try {
      if (!await _ensureLoggedIn(message: '상품 구매는 로그인 후 이용할 수 있습니다.')) {
        return;
      }
      final pendingQty = _pendingQtyUpdate;
      if (pendingQty != null) await pendingQty;
      if (!mounted) return;
      await _refreshSelectedShipping();
      if (!mounted) return;
      final priceChanged = await _loadCart(forceRefresh: true);
      if (!mounted || priceChanged) return;

      final selectedCartItems = _displayedCartItems
          .where((item) => selectedIds.contains(item.ctId) && item.isAvailable)
          .toList(growable: false);
      if (selectedCartItems.isEmpty) {
        AppToastOverlay.show(context, '판매 가능한 상품을 선택해 주세요.');
        return;
      }

      final navigator = Navigator.of(context, rootNavigator: true);
      final paid = await navigator.push<bool>(
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
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(context, '주문/결제 화면을 열지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => _checkoutOpening = false);
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

  Widget _buildPageCenteredEmpty(Widget empty) {
    final header = widget.scrollHeader;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (header != null)
          Align(alignment: Alignment.topCenter, child: header),
        PageCenteredEmptyOverlay(child: empty),
      ],
    );
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
    if (isLoading && cartItems.isEmpty) {
      return _wrapWithOptionalHeader(
        const Center(child: CircularProgressIndicator(color: const Color(0xFFFF5A8D))),
      );
    }
    if (needsLogin) {
      return _buildPageCenteredEmpty(
        CenteredEmptyState(
          iconWidget: CenteredEmptyState.assetIcon(
            context,
            AppAssets.emptyCartIcon,
          ),
          message: '로그인 후 이용 가능합니다.',
          trailing: CenteredEmptyState.loginButtonTrailing(
            context,
            onPressed: () async {
              await Navigator.pushNamed(context, '/login');
              if (!mounted) return;
              await _loadCart(forceRefresh: true);
            },
          ),
        ),
      );
    }
    if (errorMessage != null && _displayedCartItems.isEmpty) {
      return _buildPageCenteredEmpty(
        LoadFailureNotice(
          message: '장바구니를 불러오지 못했습니다.',
          onRetry: () => _loadCart(forceRefresh: true),
        ),
      );
    }
    if (_displayedCartItems.isEmpty) {
      return _buildPageCenteredEmpty(
        CenteredEmptyState(
          iconWidget: CenteredEmptyState.assetIcon(
            context,
            AppAssets.emptyCartIcon,
          ),
          message: '장바구니에 담긴 상품이 없습니다',
          subtitle: '원하는 상품을 담아보세요',
          subtitleStyle: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
          trailing: [
            CartEmptyShopButton(prescriptionTab: false),
          ],
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
              healthDp(context, 20),
              healthDp(context, 8),
              healthDp(context, 20),
              0,
            ),
            topBar: _buildSelectAllRow(),
            scrollChild: RefreshIndicator(
              onRefresh: () => _loadCart(
                showCachedData: false,
                forceRefresh: true,
              ),
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
                    if (widget.scrollHeader != null) widget.scrollHeader!,
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        healthDp(context, 20),
                        widget.scrollHeader != null ? 0 : healthDp(context, 16),
                        healthDp(context, 20),
                        healthDp(context, 16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildSelectAllRow(),
                          SizedBox(height: healthDp(context, 10)),
                          ...groupCartByVendor(_displayedGroups).expand(
                            (entry) => [
                              CartGroupGeneralCard(
                                vendorName: entry.key,
                                groups: entry.value,
                                selectedItems: selectedItems,
                                nestSupplyAdds: true,
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
                                    QuantityStepper(
                                  quantity: quantity,
                                  onDecrease: onDecrease,
                                  onIncrease: onIncrease,
                                ),
                                onToggleVendor: (selected) {
                                  setState(() {
                                    final ids = entry.value
                                        .expand((g) => g.allItems)
                                        .where((e) => e.isAvailable)
                                        .map((e) => e.ctId);
                                    if (selected) {
                                      selectedItems.addAll(ids);
                                    } else {
                                      selectedItems.removeAll(ids);
                                    }
                                    selectAll =
                                        _availableDisplayedItemIds.isNotEmpty &&
                                            _availableDisplayedItemIds
                                                .difference(selectedItems)
                                                .isEmpty;
                                  });
                                  _persistCartSelection();
                                },
                                onToggleItem: (item, selected) {
                                  if (!item.isAvailable) return;
                                  setState(() {
                                    if (selected) {
                                      selectedItems.add(item.ctId);
                                      for (final g in _displayedGroups) {
                                        if (g.parent.ctId == item.ctId) {
                                          for (final c in g.children) {
                                            if (c.isAvailable) {
                                              selectedItems.add(c.ctId);
                                            }
                                          }
                                        }
                                      }
                                    } else {
                                      selectedItems.remove(item.ctId);
                                      for (final g in _displayedGroups) {
                                        if (g.parent.ctId == item.ctId) {
                                          for (final c in g.children) {
                                            selectedItems.remove(c.ctId);
                                          }
                                        }
                                      }
                                    }
                                    selectAll =
                                        _availableDisplayedItemIds.isNotEmpty &&
                                            _availableDisplayedItemIds
                                                .difference(selectedItems)
                                                .isEmpty;
                                  });
                                  _persistCartSelection();
                                },
                                onQuantityChanged: (item, qty) =>
                                    _updateQuantity(item.ctId, qty),
                                onDelete: (item) => _deleteCartItem(item.ctId),
                                onOpenDetail: _openCartProductDetail,
                              ),
                              SizedBox(height: healthDp(context, 10)),
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
                          SizedBox(height: healthDp(context, 10)),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryRow(
          '총 구매 금액',
          '${PriceFormatter.format(selectedPrice)}원',
          fontSize: healthSp(context, 14),
          fontWeight: FontWeight.w500,
          labelColor: const Color(0xFF898686),
          valueColor: const Color(0xFF1A1A1E),
        ),
        SizedBox(height: healthDp(context, 10)),
        _summaryRow(
          '배송비',
          '${PriceFormatter.format(selectedShipping)}원',
          fontSize: healthSp(context, 14),
          fontWeight: FontWeight.w500,
          labelColor: const Color(0xFF898686),
          valueColor: const Color(0xFF1A1A1E),
        ),
        SizedBox(height: healthDp(context, 10)),
        const SizedBox(
          width: double.infinity,
          height:  1.5,
          child: ColoredBox(color: Color(0x7FD2D2D2)),
        ),
        SizedBox(height: healthDp(context, 10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '결제 예정 금액',
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 20),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: healthDp(context, 20)),
            Expanded(
              child: Text(
                '${PriceFormatter.format(payable)}원',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontSize: healthSp(context, 20),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    final selected = _selectedDisplayedItemIds;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 10),
        healthDp(context, 10),
        healthDp(context, 10),
        healthDp(context, 10) + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: healthDp(context, 45),
        child: ElevatedButton(
          onPressed: selected.isEmpty || _checkoutOpening
              ? null
              : () => _openPaymentScreen(Set<int>.from(selected)),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, healthDp(context, 45)),
            maximumSize: Size(double.infinity, healthDp(context, 45)),
            padding: EdgeInsets.zero,
            backgroundColor: const Color(0xFFFF5A8D),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: _checkoutOpening
              ? SizedBox(
                  width: healthDp(context, 20),
                  height: healthDp(context, 20),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _lightCheckbox(
              base: 20,
              value: _availableDisplayedItemIds.isNotEmpty &&
                  _availableDisplayedItemIds.difference(selectedItems).isEmpty,
              onChanged: (bool? value) {
                setState(() {
                  final shouldSelect = value ?? false;
                  if (shouldSelect) {
                    selectedItems.addAll(_availableDisplayedItemIds);
                  } else {
                    selectedItems.removeAll(_displayedItemIds);
                  }
                  selectAll = _availableDisplayedItemIds.isNotEmpty &&
                      _availableDisplayedItemIds
                          .difference(selectedItems)
                          .isEmpty;
                });
                _persistCartSelection();
              },
            ),
            SizedBox(width: healthDp(context, 5)),
            Text(
              '전체 선택',
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasSoldOutItems) ...[
              InkWell(
                onTap: _deleteSoldOutItems,
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 14),
                    vertical: healthDp(context, 10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 1),
                        color: const Color(0xFFEBEBEB),
                      ),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 50)),
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.86,
                    child: Text(
                      '품절삭제',
                      style: TextStyle(
                        color: const Color(0xFFD2D2D2),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 8)),
            ],
            InkWell(
              onTap: _selectedDisplayedItemIds.isEmpty
                  ? null
                  : () => _deleteSelectedItems(),
              borderRadius: BorderRadius.circular(healthDp(context, 50)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 14),
                  vertical: healthDp(context, 10),
                ),
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: const Color(0xFFF9F9F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  ),
                ),
                child: Text(
                  '선택삭제',
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lightCheckbox({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    double base = 20,
  }) {
    final boxSize = healthDp(context, base);
    final scale = boxSize / 18;
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
    Color labelColor = const Color(0xFF1A1A1A),
    Color valueColor = const Color(0xFF1A1A1A),
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            color: labelColor,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: fontWeight,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            color: valueColor,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  void _openCartProductDetail(CartItem item) {
    final kind = (item.itKind ?? item.ctKind).trim().toLowerCase();
    final route = kind == 'prescription'
        ? '/product/${item.itId}'
        : '/product-general/${item.itId}';
    Navigator.pushNamed(context, route);
  }

}
