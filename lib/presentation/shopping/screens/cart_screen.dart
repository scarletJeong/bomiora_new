import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/price_formatter.dart';
import 'payment_screen.dart';
import '../widgets/recommend_product.dart';
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
  List<Product> _recommendedProducts = [];
  bool isLoading = true;
  bool isRefreshing = false; // 새로고침 중인지 (캐시된 데이터 표시 중)
  String? errorMessage;
  int shippingCost = 0; // 배송비
  int totalPrice = 0; // 총구매금액
  Set<int> selectedItems = {}; // 선택된 아이템의 ctId 집합
  bool selectAll = false; // 현재 탭의 전체 선택 상태

  List<CartItem> get _displayedCartItems {
    // 탭 제거: 처방상품 장바구니만 노출
    return cartItems.where((item) => item.isPrescription).toList();
  }

  Set<int> get _displayedItemIds {
    return _displayedCartItems.map((item) => item.ctId).toSet();
  }

  Set<int> get _selectedDisplayedItemIds {
    return selectedItems.intersection(_displayedItemIds);
  }

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadRecommendedProductsForCart();
  }

  Future<void> _loadRecommendedProductsForCart() async {
    try {
      final results = await Future.wait([
        ProductRepository.getProductsByCategory(
          categoryId: '10',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: '20',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: '80',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
      ]);
      final merged = results.expand((e) => e).toList();
      if (!mounted) return;
      setState(() {
        _recommendedProducts = merged;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendedProducts = [];
      });
    }
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
                print('⚠️ [장바구니 아이템 파싱 오류]: $e');
                return null;
              }
            })
            .whereType<CartItem>() // null 제거
            .toList();
        setState(() {
          cartItems = items;
          shippingCost = (result['shipping_cost'] as int?) ?? 0;
          totalPrice = (result['total_price'] as int?) ?? 0;

          // 사라진 아이템의 선택 상태는 제거하고, 현재 탭 전체선택 상태면 현재 탭 아이템만 재선택
          final existingIds = items.map((item) => item.ctId).toSet();
          selectedItems = selectedItems.where(existingIds.contains).toSet();
          if (selectAll) {
            selectedItems.addAll(_displayedItemIds);
          }
          selectAll = _displayedCartItems.isNotEmpty &&
              _displayedItemIds.difference(selectedItems).isEmpty;

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
    if (newQuantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수량은 1개 이상이어야 합니다')),
      );
      return;
    }

    // 백엔드 API 호출로 수량 업데이트
    final result = await CartService.updateCartQuantity(
      ctId: ctId,
      quantity: newQuantity,
    );

    if (result['success'] == true) {
      // 성공 시 장바구니 다시 로드 (캐시된 데이터를 표시하면서 백그라운드 갱신)
      _loadCart(showCachedData: true);
    } else {
      // 실패 시 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '수량 변경에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCartItem(int ctId) async {
    if (!await _ensureLoggedIn(message: '장바구니 수정은 로그인 후 이용할 수 있습니다.')) {
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: '삭제 확인',
      message: '장바구니에서 이 상품을 /n삭제하시겠습니까?',
      cancelText: '취소',
      confirmText: '삭제',
    );

    if (confirmed) {
      final result = await CartService.removeCartItem(ctId);
      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장바구니에서 삭제되었습니다')),
        );
        // 선택된 아이템에서도 제거
        setState(() {
          selectedItems.remove(ctId);
        });
        _loadCart(showCachedData: true); // 장바구니 다시 로드 (캐시 표시)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '삭제에 실패했습니다.')),
        );
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

    final confirmed = await ConfirmDialog.show(
      context,
      title: '삭제 확인',
      message:
          '선택한 ${selectedDisplayedItems.length}개 상품을 장바구니에서 삭제하시겠습니까?',
      cancelText: '취소',
      confirmText: '삭제',
    );

    if (confirmed) {
      // 선택된 아이템들을 순차적으로 삭제
      final itemsToDelete = List<int>.from(selectedDisplayedItems);
      int successCount = 0;
      int failCount = 0;

      for (int ctId in itemsToDelete) {
        final result = await CartService.removeCartItem(ctId);
        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      }

      // 선택 상태 초기화
      setState(() {
        selectedItems.removeAll(itemsToDelete);
        selectAll = false;
      });

      // 결과 메시지 표시
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${successCount}개 상품이 장바구니에서 삭제되었습니다')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${successCount}개 삭제 완료, ${failCount}개 삭제 실패'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadCart(showCachedData: true); // 장바구니 다시 로드 (캐시 표시)
    }
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
    if (_selectedDisplayedItemIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제할 상품을 선택해 주세요.')),
      );
      return;
    }

    final selectedCartItems = _displayedCartItems
        .where((item) => _selectedDisplayedItemIds.contains(item.ctId))
        .toList();
    if (selectedCartItems.isEmpty) return;

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          cartItems: selectedCartItems,
          shippingCost: selectedShippingCost,
          sourceTitle: '처방상품 장바구니',
        ),
      ),
    );

    if (!mounted) return;
    if (paid == true) {
      await _loadCart(showCachedData: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제가 완료되어 앱으로 돌아왔습니다.')),
      );
    }
  }

  void _handleBackNavigation() {
    final backToProductId = widget.backToProductId;
    if (backToProductId != null && backToProductId.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/product/$backToProductId');
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
          title: '처방상품 장바구니',
          centerTitle: true,
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCart,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : _displayedCartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '장바구니가 비어있습니다.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadCart(showCachedData: false),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 컨텐츠에 padding 적용
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 전체 선택 및 삭제 버튼 영역 (스크롤되도록 본문 안으로 이동)
                                    _buildSelectAllRow(),
                                    const SizedBox(height: 12),

                                    // 상품 목록
                                    ..._displayedCartItems.expand(
                                      (item) => [
                                        _buildCartItemCard(item),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                    if (_displayedCartItems.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 40),
                                        child: Text(
                                          '선택한 탭에 상품이 없습니다.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 16),

                                    // 안내 문구
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '*진료예약자와 시간을 다시 한번 확인해주세요.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '결제가 완료되셔야 예약이 확정됩니다.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFFF3787),
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    // 결제 요약(하단 고정 제거 → 본문으로 이동)
                                    _buildFigmaBottomSummary(
                                      inPage: true,
                                    ),
                                    const SizedBox(height: 18),

                                    if (_recommendedProducts.isNotEmpty) ...[
                                      // 추가 상품 구매하기 섹션 라벨
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Text(
                                                '|',
                                                style: TextStyle(
                                                  color: Color(0xFF1A1A1A),
                                                  fontSize: 16,
                                                  fontFamily: 'Gmarket Sans TTF',
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -1.44,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                '추가 상품 구매하기',
                                                style: TextStyle(
                                                  color: Color(0xFF1A1A1A),
                                                  fontSize: 16,
                                                  fontFamily: 'Gmarket Sans TTF',
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -1.44,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '함께 구매하면 좋은 상품을 확인해보세요 !',
                                            style: TextStyle(
                                              color: Color(0xFF898686),
                                              fontSize: 12,
                                              fontFamily: 'Gmarket Sans TTF',
                                              fontWeight: FontWeight.w500,
                                              height: 1.32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: RecommendProductSection(
                                          excludedProductNames:
                                              _displayedCartItems
                                                  .map((e) => e.itName)
                                                  .toList(),
                                          products: _recommendedProducts,
                                          title: '추가 상품 구매하기',
                                          showLeadingBar: false,
                                          onProductTap: (product) {
                                            Navigator.pushNamed(
                                              context,
                                              '/product/${product.id}',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }

  Widget _buildFigmaBottomSummary({bool inPage = false}) {
    // 기존 계산 로직/선택 로직을 재사용하면서, 하단 영역을 Figma 느낌으로 고정
    final selected = _selectedDisplayedItemIds;
    final selectedPrice = selectedTotalPrice;
    final selectedShipping = selectedShippingCost;
    final payable = finalPrice;

    final content = Container(
      color: Colors.white,
      padding: inPage
          ? const EdgeInsets.fromLTRB(10, 14, 0, 16)
          : const EdgeInsets.fromLTRB(17, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _summaryRow('구매금액', '${PriceFormatter.format(selectedPrice)}원',
              fontSize: 16, fontWeight: FontWeight.w500),
          const SizedBox(height: 10),
          _summaryRow('배송비', '${PriceFormatter.format(selectedShipping)}원',
              fontSize: 14, fontWeight: FontWeight.w500),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0x7F1A1A1A)),
          const SizedBox(height: 10),
          _summaryRow('결제 예정 금액', '${PriceFormatter.format(payable)}원',
              fontSize: 16, fontWeight: FontWeight.w700),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: selected.isEmpty ? null : _openPaymentScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A8D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '결제하기',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (inPage) return content;
    return SafeArea(top: false, child: content);
  }

  Widget _buildSelectAllRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
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
                },
              ),
              const SizedBox(width: 4),
              const Text(
                '전체선택',
                style: TextStyle(
                  fontSize: 13,
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('품절삭제 기능은 추후 구현 예정입니다')),
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '품절삭제',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _selectedDisplayedItemIds.isEmpty
                    ? null
                    : () => _deleteSelectedItems(),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '선택삭제',
                  style: TextStyle(
                    fontSize: 12,
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
    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

  static const TextStyle _kCartOptionMuted = TextStyle(
    color: Color(0xFF898383),
    fontSize: 10,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w500,
    letterSpacing: -0.90,
  );

  bool _isPrescriptionKind(CartItem item) =>
      item.ctKind.trim().toLowerCase() == 'prescription';

  /// 처방: 기존 옵션 줄 뒤에 `| 수량 : N개` (이미지 열은 그대로)
  Widget _buildPrescriptionOptionRowWithQty(CartItem item) {
    final opt = _buildCartItemOptionRow(item);
    final qtyText = Text(
      '수량 : ${item.ctQty}개',
      style: _kCartOptionMuted,
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
          width: 0.5,
          height: 10,
          color: const Color(0xFF898686),
        ),
        const SizedBox(width: 5),
        qtyText,
      ],
    );
  }

  static const TextStyle _kPrescriptionMetaLabel = TextStyle(
    color: Color(0xFF1A1A1A),
    fontSize: 12,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle _kPrescriptionMetaValue = TextStyle(
    color: Color(0xFFFF5A8D),
    fontSize: 12,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  String _formatCartReservationDate(CartItem item) {
    final d = item.reservationDate;
    if (d == null) return '-';
    return DateDisplayFormatter.formatYmd(d);
  }

  String _formatCartReservationTime(CartItem item) {
    final raw = item.reservationTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw;
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
            Text('$left ', style: _kCartOptionMuted),
            Container(
              width: 0.5,
              height: 10,
              color: const Color(0xFF898686),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                right,
                style: _kCartOptionMuted,
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
              style: _kCartOptionMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 0.5,
            height: 10,
            color: const Color(0xFF898686),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              opt,
              style: _kCartOptionMuted,
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
        style: _kCartOptionMuted,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (sub.isNotEmpty) {
      return Text(
        sub,
        style: _kCartOptionMuted,
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
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
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
                    },
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _deleteCartItem(item.ctId),
                borderRadius: BorderRadius.circular(10),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(Icons.close, size: 18, color: Color(0xFF1A1A1A)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/product/${item.itId}'),
                  child: CartItemThumbnail(item: item, size: 87),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categoryLabel != null) ...[
                        Text(
                          categoryLabel,
                          style: const TextStyle(
                            color: Color(0xFF898686),
                            fontSize: 8,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        item.itName,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.26,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isPrescription) ...[
                        const SizedBox(height: 5),
                        _buildPrescriptionOptionRowWithQty(item),
                        const SizedBox(height: 10),
                        Text(
                          '${PriceFormatter.format(item.ctPrice)}원',
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          height: 0.5,
                          color: const Color(0x7FD2D2D2),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: '담당 한의사 ',
                                style: _kPrescriptionMetaLabel,
                              ),
                              TextSpan(
                                text: '정대진',
                                style: _kPrescriptionMetaValue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: '예약 일자 ',
                                style: _kPrescriptionMetaLabel,
                              ),
                              TextSpan(
                                text: _formatCartReservationDate(item),
                                style: _kPrescriptionMetaValue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: '예약 시간 ',
                                style: _kPrescriptionMetaLabel,
                              ),
                              TextSpan(
                                text: _formatCartReservationTime(item),
                                style: _kPrescriptionMetaValue,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        if (optionRow != null) ...[
                          const SizedBox(height: 5),
                          optionRow,
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text(
                              '수량',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
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
              padding: const EdgeInsets.only(top: 15),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    width: 0.5,
                    color: Color(0x7FD2D2D2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${PriceFormatter.format(item.ctPrice)}원',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
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

  Widget _buildFigmaQtyControl({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFigmaQtyButton(icon: Icons.remove, onTap: onDecrease),
          SizedBox(
            width: 18,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 12,
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 20,
        height: 20,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 1.07,
              offset: Offset(0, 0.54),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 14,
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
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$price원',
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
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
