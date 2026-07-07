import 'package:flutter/material.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/scroll_reveal_top_overlay.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/price_formatter.dart';
import 'payment_screen.dart';
import '../widgets/get_cartImage.dart';

class CartScreen extends StatefulWidget {
  final String? backToProductId;
  final int initialTabIndex;

  const CartScreen({
    super.key,
    this.backToProductId,
    this.initialTabIndex = 0,
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

  List<CartItem> get _displayedCartItems {
    // 일반상품 장바구니 화면: 일반상품만 노출
    return cartItems.where((item) => !item.isPrescription).toList();
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

      totalPrice = cartItems.fold<int>(0, (sum, item) => sum + item.ctPrice);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${itemsToDelete.length}개 상품 삭제 완료'),
        duration: const Duration(seconds: 2),
      ),
    );

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
        sum += item.ctPrice;
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

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '일반상품 장바구니',
          centerTitle: false,
          onBack: _handleBackNavigation,
          actions: const [],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
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
                  )
                : _displayedCartItems.isEmpty
                    ? const CenteredEmptyState(
                        icon: Icons.shopping_cart_outlined,
                        message: '장바구니가 비어있습니다.',
                      )
                    : Column(
                    children: [
                      Expanded(
                        child: ScrollRevealTopOverlay(
                          controller: _scrollController,
                          revealAfterOffset: healthDp(context, 44),
                          barPadding: EdgeInsets.fromLTRB(
                            healthDp(context, 16),
                            healthDp(context, 8),
                            healthDp(context, 16),
                            0,
                          ),
                          topBar: _buildSelectAllRow(),
                          scrollChild: RefreshIndicator(
                            onRefresh: () => _loadCart(showCachedData: false),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(healthDp(context, 16)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _buildSelectAllRow(),
                                        SizedBox(height: healthDp(context, 12)),
                                        ..._displayedCartItems.expand(
                                          (item) => [
                                            _buildCartItemCard(item),
                                            SizedBox(height: healthDp(context, 12)),
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
                  ),
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

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 17),
          healthDp(context, 10),
          healthDp(context, 20),
          healthDp(context, 20),
        ),
        child: SizedBox(
          width: double.infinity,
          height: healthDp(context, 40),
          child: ElevatedButton(
            onPressed: selected.isEmpty ? null : _openPaymentScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A8D),
              foregroundColor: Colors.white,
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
      ),
    );
  }

  Widget _buildSelectAllRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
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
                    color: _selectedDisplayedItemIds.isEmpty
                        ? Colors.grey
                        : Colors.red,
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

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Theme(
            data: Theme.of(context).copyWith(
              checkboxTheme: CheckboxThemeData(
                side: BorderSide(
                  color: const Color(0xFFD2D2D2),
                  width: healthDp(context, 1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 4)),
                ),
              ),
            ),
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFF5A8D),
              checkColor: Colors.white,
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

  TextStyle _cartOptionMutedStyle() => TextStyle(
        color: const Color(0xFF898383),
        fontSize: healthSp(context, 10),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        letterSpacing: healthSp(context, -0.90),
      );

  bool _isPrescriptionKind(CartItem item) =>
      item.ctKind.trim().toLowerCase() == 'prescription';

  /// 처방: 기존 옵션 줄 뒤에 `| 수량 : N개` (이미지 열은 그대로)
  Widget _buildPrescriptionOptionRowWithQty(CartItem item) {
    final opt = _buildCartItemOptionRow(item);
    final qtyText = Text(
      '수량 : ${item.ctQty}개',
      style: _cartOptionMutedStyle(),
    );
    if (opt == null) {
      return qtyText;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: opt,
        ),
        Container(
          width: healthDp(context, 0.5),
          height: healthDp(context, 10),
          color: const Color(0xFF898686),
        ),
        SizedBox(width: healthDp(context, 5)),
        qtyText,
      ],
    );
  }

  TextStyle _prescriptionMetaLineStyle() => TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: healthSp(context, 12),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        height: 1.35,
      );

  String _formatCartReservationDate(CartItem item) {
    final d = item.reservationDate;
    if (d == null) return '-';
    return DateDisplayFormatter.formatYmd(d);
  }

  /// 옵션/규격 줄 — `ct_option`의 ` / ` 또는 `it_subject` + `ct_option` 조합
  Widget? _buildCartItemOptionRow(CartItem item) {
    final opt = item.ctOption.trim();
    final sub = item.itSubject?.trim() ?? '';

    if (opt.contains(' / ')) {
      final parts = opt
          .split(' / ')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        final left = parts.first;
        final right = parts.sublist(1).join(' / ');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$left ', style: _cartOptionMutedStyle()),
            Container(
              width: healthDp(context, 0.5),
              height: healthDp(context, 10),
              color: const Color(0xFF898686),
            ),
            SizedBox(width: healthDp(context, 5)),
            Flexible(
              child: Text(
                right,
                style: _cartOptionMutedStyle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }
    }
    if (sub.isNotEmpty && opt.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$sub ',
              style: _cartOptionMutedStyle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: healthDp(context, 0.5),
            height: healthDp(context, 10),
            color: const Color(0xFF898686),
          ),
          SizedBox(width: healthDp(context, 5)),
          Flexible(
            child: Text(
              opt,
              style: _cartOptionMutedStyle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (opt.isNotEmpty) {
      return Text(
        opt,
        style: _cartOptionMutedStyle(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (sub.isNotEmpty) {
      return Text(
        sub,
        style: _cartOptionMutedStyle(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return null;
  }

  Widget _buildCartItemCard(CartItem item) {
    final isSelected = selectedItems.contains(item.ctId);
    final isPrescription = _isPrescriptionKind(item);
    final categoryLabel = (item.productType != null &&
            item.productType!.trim().isNotEmpty)
        ? item.productType!.trim()
        : (item.isPrescription ? '한의약품' : null);
    final optionRow = _buildCartItemOptionRow(item);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: healthDp(context, 20),
                height: healthDp(context, 20),
                child: Center(
                  child: _lightCheckbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value ?? false) {
                          selectedItems.add(item.ctId);
                        } else {
                          selectedItems.remove(item.ctId);
                        }
                        selectAll = _displayedCartItems.isNotEmpty &&
                            _displayedItemIds.difference(selectedItems).isEmpty;
                      });
                      _persistCartSelection();
                    },
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _deleteCartItem(item.ctId),
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: SizedBox(
                  width: healthDp(context, 20),
                  height: healthDp(context, 20),
                  child: Icon(
                    Icons.close,
                    size: healthDp(context, 18),
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openGeneralProductDetail(item.itId),
                  child: CartItemThumbnail(
                    item: item,
                    size: healthDp(context, 87),
                  ),
                ),
                SizedBox(width: healthDp(context, 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categoryLabel != null) ...[
                        Text(
                          categoryLabel,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 8),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 2)),
                      ],
                      GestureDetector(
                        onTap: () => _openGeneralProductDetail(item.itId),
                        child: Text(
                          item.itName,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            letterSpacing: healthSp(context, -1.26),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPrescription) ...[
                        SizedBox(height: healthDp(context, 5)),
                        _buildPrescriptionOptionRowWithQty(item),
                        SizedBox(height: healthDp(context, 10)),
                        Text(
                          '${PriceFormatter.format(item.ctPrice)}원',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 10)),
                        Container(
                          width: double.infinity,
                          height: healthDp(context, 0.5),
                          color: const Color(0x7FD2D2D2),
                        ),
                        SizedBox(height: healthDp(context, 10)),
                        Text(
                          '담당 한의사 정대진',
                          style: _prescriptionMetaLineStyle(),
                        ),
                        SizedBox(height: healthDp(context, 4)),
                        Text(
                          '예약 일자 ${_formatCartReservationDate(item)}',
                          style: _prescriptionMetaLineStyle(),
                        ),
                        SizedBox(height: healthDp(context, 4)),
                        Text(
                          '예약 시간 ${item.reservationTime?.trim().isNotEmpty == true ? item.reservationTime!.trim() : '-'}',
                          style: _prescriptionMetaLineStyle(),
                        ),
                      ] else ...[
                        if (optionRow != null) ...[
                          SizedBox(height: healthDp(context, 5)),
                          optionRow,
                        ],
                        SizedBox(height: healthDp(context, 10)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              '수량',
                              style: TextStyle(
                                color: const Color(0xFF1A1A1A),
                                fontSize: healthSp(context, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: healthDp(context, 10)),
                            _buildFigmaQtyControl(
                              quantity: item.ctQty,
                              onDecrease: item.ctQty > 1
                                  ? () =>
                                      _updateQuantity(item.ctId, item.ctQty - 1)
                                  : null,
                              onIncrease: () =>
                                  _updateQuantity(item.ctId, item.ctQty + 1),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isPrescription)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: healthDp(context, 15)),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    width: healthDp(context, 0.5),
                    color: const Color(0x7FD2D2D2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${PriceFormatter.format(item.ctPrice)}원',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 16),
                      fontFamily: 'Gmarket Sans TTF',
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

  Widget _buildSummaryRow(String label, String price, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize:
                  isTotal ? healthSp(context, 15) : healthSp(context, 13),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Flexible(
          child: Text(
            '$price원',
            style: TextStyle(
              fontSize:
                  isTotal ? healthSp(context, 16) : healthSp(context, 13),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
