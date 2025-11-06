import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../core/utils/image_url_helper.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

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
  bool selectAll = true; // 전체 선택 상태 (기본값: true)

  @override
  void initState() {
    super.initState();
    _loadCart();
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
        final items = (result['data'] as List)
            .map((item) => CartItem.fromJson(item))
            .toList();
        setState(() {
          cartItems = items;
          shippingCost = (result['shipping_cost'] as int?) ?? 0;
          totalPrice = (result['total_price'] as int?) ?? 0;
          
          // 기본값으로 전체 선택
          if (selectAll) {
            selectedItems = items.map((item) => item.ctId).toSet();
          }
          
          isLoading = false;
          isRefreshing = false;
        });
      } else {
        setState(() {
          if (!hasCachedData) {
            errorMessage = result['message'] ?? '장바구니를 불러오는데 실패했습니다.';
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

  String _getImageUrl(CartItem item) {
    // ImageUrlHelper를 사용하여 이미지 URL 정규화 (https:// 처리 포함)
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      // normalizeThumbnailUrl을 사용하여 data/item/ 경로 포함 및 https:// 처리
      final normalized = ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    // 기본 이미지 반환
    final defaultImage = ImageUrlHelper.normalizeThumbnailUrl('no_img.png', item.itId);
    return defaultImage ?? '${ImageUrlHelper.imageBaseUrl}/data/item/${item.itId}/no_img.png';
  }

  Future<void> _updateQuantity(int ctId, int newQuantity) async {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('장바구니에서 이 상품을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('선택한 ${selectedItems.length}개 상품을 장바구니에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 선택된 아이템들을 순차적으로 삭제
      final itemsToDelete = List<int>.from(selectedItems);
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
        selectedItems.clear();
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final weekday = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${DateFormat('yyyy.MM.dd').format(date)} ${weekday[date.weekday - 1]}';
  }

  // 선택된 아이템들의 총구매금액 계산
  int get selectedTotalPrice {
    int sum = 0;
    for (var item in cartItems) {
      if (selectedItems.contains(item.ctId)) {
        sum += item.ctPrice;
      }
    }
    return sum;
  }

  // 선택된 아이템의 배송비 계산 (현재는 간단히 전체 배송비를 사용)
  // TODO: 선택된 아이템만으로 배송비를 계산하도록 백엔드 API 수정 필요
  int get selectedShippingCost {
    // 선택된 아이템이 없으면 배송비 0
    if (selectedItems.isEmpty) return 0;
    // 선택된 아이템이 전체와 같으면 전체 배송비 사용
    if (selectedItems.length == cartItems.length) {
      return shippingCost;
    }
    // 일부만 선택한 경우도 전체 배송비를 사용 (추후 백엔드에서 재계산 필요)
    return shippingCost;
  }

  int get finalPrice => selectedTotalPrice + selectedShippingCost;

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '장바구니',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        actions: [
          // 새로고침 버튼
          if (!isLoading && cartItems.isNotEmpty)
            IconButton(
              icon: isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: isRefreshing
                  ? null
                  : () => _loadCart(showCachedData: true),
              tooltip: '새로고침',
            ),
        ],
      ),
      child: isLoading
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
              : cartItems.isEmpty
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
                  : Column(
                      children: [
                        // 전체 선택 및 삭제 버튼 영역
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              // 전체 선택 체크박스
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: selectAll && selectedItems.length == cartItems.length,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          selectAll = value ?? false;
                                          if (selectAll) {
                                            selectedItems = cartItems.map((item) => item.ctId).toSet();
                                          } else {
                                            selectedItems.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const Flexible(
                                      child: Text(
                                        '전체선택',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 품절삭제, 선택삭제 버튼
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        // TODO: 품절 상품 삭제 기능 구현
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('품절삭제 기능은 추후 구현 예정입니다')),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                      onPressed: selectedItems.isEmpty
                                          ? null
                                          : () => _deleteSelectedItems(),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        '선택삭제',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: selectedItems.isEmpty ? Colors.grey : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 상품 목록
                                ...cartItems.map((item) => _buildCartItemCard(item)),
                                
                                const SizedBox(height: 16),
                                
                                // 안내 문구
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
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
                                        '결제가 완료되셔야 예약이 확정됩니다',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // 결제 요약
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow('총구매금액', _formatPrice(selectedTotalPrice), isTotal: false),
                              const SizedBox(height: 8),
                              _buildSummaryRow('배송비', _formatPrice(selectedShippingCost), isTotal: false),
                              const Divider(height: 24),
                              _buildSummaryRow('결제금액', _formatPrice(finalPrice), isTotal: true),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // 결제 페이지로 이동 (추후 구현)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('결제 기능은 추후 구현 예정입니다')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF3787),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    '결제하기',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    final isSelected = selectedItems.contains(item.ctId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 0, top: 16, right: 16, bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 선택 체크박스
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value ?? false) {
                        selectedItems.add(item.ctId);
                      } else {
                        selectedItems.remove(item.ctId);
                      }
                      // 전체 선택 상태 업데이트
                      selectAll = selectedItems.length == cartItems.length;
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                // 상품 이미지 (data/item/{it_id}/...jpg 형식)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getImageUrl(item),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    cacheWidth: 100, // 메모�?최적??
                    cacheHeight: 100,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 상품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상품 타입 태그
                      if (item.productType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.productType!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      
                      if (item.productType != null) const SizedBox(height: 8),
                      
                      // 상품명
                      Text(
                        item.itName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // 상품 설명
                      if (item.itSubject != null && item.itSubject!.isNotEmpty)
                        Text(
                          item.itSubject!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // 옵션 표시 (ct_option)
                      if (item.ctOption.isNotEmpty)
                        Text(
                          item.ctOption,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      if (item.ctOption.isNotEmpty) const SizedBox(height: 8),
                      
                      // 수량 및 금액 (수량 조정 가능)
                      Row(
                        children: [
                          const Text(
                            '수량: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          // 수량 감소 버튼
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                            onPressed: item.ctQty > 1 ? () => _updateQuantity(item.ctId, item.ctQty - 1) : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          Text(
                            '${item.ctQty}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          // 수량 증가 버튼
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            onPressed: () => _updateQuantity(item.ctId, item.ctQty + 1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.formattedPrice}원',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // 처방 상품인 경우 예약 정보
                      if (item.isPrescription && item.doctorName != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '담당 의사: ${item.doctorName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF3787),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.reservationDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '예약일자: ${_formatDate(item.reservationDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF3787),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.reservationTime != null && item.reservationTime!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '예약 시간: ${item.reservationTime}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF3787),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 삭제 버튼
          Positioned(
            top: 8,
            right: 8,
            child: ElevatedButton(
              onPressed: () => _deleteCartItem(item.ctId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3787),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                '삭제',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
