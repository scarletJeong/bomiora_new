import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import 'delivery_detail_screen.dart';
import '../review/review_write_screen.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../../core/utils/image_url_helper.dart';

/// 주문/배송 조회 화면
class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '1개월'; // 선택된 기간
  
  // 주문 데이터
  List<OrderListModel> _orders = [];
  bool _isLoading = false;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _hasNext = false;

  // 주문 상태 탭
  final List<String> _orderStatusTabs = [
    '전체',
    '결제완료',
    '배송준비중',
    '배송중',
    '배송완료',
    '취소/반품',
  ];

  // 기간 필터
  final List<String> _periodFilters = ['1개월', '3개월', '6개월', '전체'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _orderStatusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  /// 탭 변경 이벤트
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadOrders();
    }
  }
  
  /// 주문 목록 로드
  Future<void> _loadOrders() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 로그인된 사용자 ID 가져오기
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }
      final userId = user.id;
      
      // 기간 계산
      int period = 0;
      switch (_selectedPeriod) {
        case '1개월':
          period = 1;
          break;
        case '3개월':
          period = 3;
          break;
        case '6개월':
          period = 6;
          break;
        case '전체':
          period = 0;
          break;
      }
      
      // 상태 매핑
      String status = 'all';
      final currentTab = _orderStatusTabs[_tabController.index];
      switch (currentTab) {
        case '전체':
          status = 'all';
          break;
        case '결제완료':
          status = 'payment';
          break;
        case '배송준비중':
          status = 'preparing';
          break;
        case '배송중':
          status = 'delivering';
          break;
        case '배송완료':
          status = 'finish';
          break;
        case '취소/반품':
          status = 'cancel';
          break;
      }
      
      // API 호출
      final result = await OrderService.getOrderList(
        mbId: userId,
        period: period,
        status: status,
        page: 0,
        size: 50,
      );
      
      if (result['success'] == true) {
        setState(() {
          _orders = result['orders'] as List<OrderListModel>;
          _currentPage = result['currentPage'] ?? 0;
          _totalPages = result['totalPages'] ?? 0;
          _hasNext = result['hasNext'] ?? false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 목록을 불러올 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      print('❌ 주문 목록 로드 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문 목록을 불러오는 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            '주문/배송 조회',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            // 기간 필터
            _buildPeriodFilter(),
            const SizedBox(height: 8),

            // 주문 상태 탭
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start, // 탭을 왼쪽 정렬
                padding: const EdgeInsets.symmetric(horizontal: 8), // 좌우 패딩 최소화
                indicatorColor: const Color(0xFFFF4081),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF4081),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                tabs: _orderStatusTabs
                    .map((status) => Tab(text: status))
                    .toList(),
              ),
            ),

            // 주문 목록
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _orderStatusTabs
                    .map((status) => _buildOrderList(status))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 기간 필터 위젯
  Widget _buildPeriodFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _periodFilters.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
                _loadOrders(); // API 다시 호출
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF4081) : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF4081)
                        : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 주문 목록 위젯
  Widget _buildOrderList(String status) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(
        color: Color(0xFFFF4081),
      ));
    }

    // 현재 탭에 맞는 주문만 필터링
    List<OrderListModel> filteredOrders = _orders.where((order) {
      switch (status) {
        case '전체':
          return true;
        case '결제완료':
          return order.displayStatus == '결제완료';
        case '배송준비중':
          return order.displayStatus == '배송준비중';
        case '배송중':
          return order.displayStatus == '배송중';
        case '배송완료':
          return order.displayStatus == '배송완료';
        case '취소/반품':
          return order.displayStatus == '취소/반품';
        default:
          return true;
      }
    }).toList();

    if (filteredOrders.isEmpty) {
      return _buildEmptyState(status);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFFFF4081),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  /// 주문 카드 위젯
  Widget _buildOrderCard(OrderListModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주문 헤더 (날짜, 주문번호)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderDate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '주문번호: ${order.odId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 상품 정보
          InkWell(
            onTap: () => _navigateToOrderDetail(order.odId.toString()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품 이미지
                  _buildProductImage(order),
                  const SizedBox(width: 12),

                  // 상품 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.firstProductName ?? '상품명 없음',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (order.firstProductOption != null && order.firstProductOption!.isNotEmpty)
                          Text(
                            order.firstProductOption!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${order.firstProductQty ?? 1}개 · ${_formatPrice(order.firstProductPrice ?? 0)}원',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (order.odCartCount > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '외 ${order.odCartCount - 1}개 상품',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 주문 상태 및 액션 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 주문 상태
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.displayStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.displayStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(order.displayStatus),
                    ),
                  ),
                ),

                // 액션 버튼 (상태별로 다르게 표시)
                Row(
                  children: [
                    // 결제완료, 배송준비중: 취소하기만
                    if (order.displayStatus == '결제완료' ||
                        order.displayStatus == '배송준비중')
                      _buildActionButton(
                        '취소하기',
                        color: Colors.red,
                        onPressed: () => _cancelOrder(order.odId),
                      ),
                    // 배송중: 배송조회만
                    if (order.displayStatus == '배송중')
                      _buildActionButton(
                        '배송조회',
                        onPressed: () =>
                            _trackDelivery(order.odId),
                      ),
                    // 배송완료: 배송확정 + 리뷰쓰기
                    if (order.displayStatus == '배송완료') ...[
                      _buildActionButton(
                        '배송확정',
                        color: const Color(0xFFFF4081),
                        onPressed: () => _confirmPurchase(order.odId),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        '리뷰쓰기',
                        color: const Color(0xFFFF4081),
                        onPressed: () => _writeReview(order.odId),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 액션 버튼 위젯
  Widget _buildActionButton(
    String text, {
    Color? color,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: color ?? Colors.grey[400]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        minimumSize: Size.zero,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color ?? Colors.grey[700],
        ),
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '$status 주문이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 주문 상세 화면으로 이동
  void _navigateToOrderDetail(String orderNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryDetailScreen(orderNumber: orderNumber),
      ),
    );
  }

  /// 주문 취소
  Future<void> _cancelOrder(int odId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 취소'),
        content: const Text('정말 주문을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 로그인 확인
              final user = await AuthService.getUser();
              if (user == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인이 필요합니다.')),
                  );
                }
                return;
              }
              final userId = user.id;
              
              // API 호출
              final result = await OrderService.cancelOrder(
                odId: odId,
                mbId: userId,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? '주문이 취소되었습니다.')),
                );
                
                if (result['success'] == true) {
                  _loadOrders(); // 목록 새로고침
                }
              }
            },
            child: const Text(
              '예',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 배송 조회
  Future<void> _trackDelivery(int odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }
      final userId = user.id;
      
      // 주문 상세 정보 조회
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );
      
      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.')),
          );
        }
        return;
      }
      
      final orderDetail = result['order'] as OrderDetailModel;
      final companyName = orderDetail.deliveryCompany;
      final trackingNumber = orderDetail.trackingNumber;
      
      // 택배사와 운송장번호 확인
      if (companyName == null || companyName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('택배사 정보가 없습니다.')),
          );
        }
        return;
      }
      
      if (trackingNumber == null || trackingNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('운송장번호가 없습니다.')),
          );
        }
        return;
      }
      
      // 지원하는 택배사인지 확인
      if (!DeliveryTracker.isSupported(companyName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$companyName은(는) 지원하지 않는 택배사입니다.')),
          );
        }
        return;
      }
      
      // 배송 조회 페이지 열기
      final success = await DeliveryTracker.openTrackingPage(companyName, trackingNumber);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배송 조회 페이지를 열 수 없습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('배송 조회 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  /// 배송확정 (구매 확정)
  Future<void> _confirmPurchase(int odId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배송확정'),
        content: const Text('배송을 확정하시겠습니까?\n확정 후에는 취소가 불가능합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 로그인 확인
              final user = await AuthService.getUser();
              if (user == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인이 필요합니다.')),
                  );
                }
                return;
              }
              final userId = user.id;
              
              // API 호출
              final result = await OrderService.confirmPurchase(
                odId: odId,
                mbId: userId,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? '배송이 확정되었습니다.'),
                    backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                  ),
                );
                
                if (result['success'] == true) {
                  _loadOrders(); // 목록 새로고침
                }
              }
            },
            child: const Text(
              '확정',
              style: TextStyle(color: Color(0xFFFF4081)),
            ),
          ),
        ],
      ),
    );
  }

  /// 리뷰 쓰기
  Future<void> _writeReview(int odId) async {
    try {
      // 로그인 확인
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }
      final userId = user.id;
      
      // 주문 상세 정보 조회
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: userId,
      );
      
      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.')),
          );
        }
        return;
      }
      
      final orderDetail = result['order'] as OrderDetailModel;
      
      // 리뷰 작성 화면으로 이동
      if (mounted) {
        final reviewWritten = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewWriteScreen(orderDetail: orderDetail),
          ),
        );
        
        // 리뷰 작성 완료 시 주문 목록 새로고침
        if (reviewWritten == true) {
          _loadOrders();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 작성 화면을 열 수 없습니다: $e')),
        );
      }
    }
  }

  /// 주문 상태별 색상
  Color _getStatusColor(String status) {
    switch (status) {
      case '결제완료':
        return Colors.blue;
      case '배송준비중':
        return Colors.orange;
      case '배송중':
        return const Color(0xFFFF4081);
      case '배송완료':
        return Colors.green;
      case '취소/반품':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 상품 이미지 위젯
  Widget _buildProductImage(OrderListModel order) {
    // 첫 번째 상품의 이미지 URL 가져오기
    String? imageUrl;
    if (order.items.isNotEmpty && order.items[0].imageUrl != null) {
      imageUrl = order.items[0].imageUrl;
    }
    
    // 이미지 URL 정규화
    final normalizedUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(imageUrl, order.items.isNotEmpty ? order.items[0].itId : null)
        : null;
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                normalizedUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.grey[400],
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: const Color(0xFFFF4081),
                    ),
                  );
                },
              ),
            )
          : Icon(
              Icons.image,
              size: 40,
              color: Colors.grey[400],
            ),
    );
  }

  /// 가격 포맷팅
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

