import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import 'delivery_detail_screen.dart';
import 'reservation_time_change_screen.dart';
import '../review/review_write_screen.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../../core/utils/image_url_helper.dart';

/// 주문내역 화면
class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  // 주문 데이터
  List<OrderListModel> _allOrders = []; // 전체 주문 데이터
  List<OrderListModel> _displayedOrders = []; // 화면에 표시할 주문 데이터
  bool _isLoading = false;
  String? _selectedStatus; // 선택된 상태 필터 (null이면 전체)
  
  // 상태별 개수
  int _orderCount = 0;      // 주문 (전체)
  int _paymentCount = 0;    // 입금 (결제완료)
  int _deliveryCount = 0;   // 배송 (배송중)
  int _completeCount = 0;   // 완료 (배송완료)
  
  // 취소/반품/교환 개수
  int _cancelCount = 0;
  int _returnCount = 0;
  int _exchangeCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 주문 목록 로드 (전체 데이터)
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
      
      // 전체 주문 데이터 조회 (기간: 전체, 상태: 전체)
      final result = await OrderService.getOrderList(
        mbId: userId,
        period: 0, // 전체 기간
        status: 'all', // 전체 상태
        page: 0,
        size: 1000, // 충분히 큰 값으로 전체 데이터 가져오기
      );
      
      if (result['success'] == true) {
        final ordersList = result['orders'] ?? [];
        List<OrderListModel> allOrders = [];
        if (ordersList is List<OrderListModel>) {
          allOrders = ordersList;
        } else if (ordersList is List) {
          allOrders = ordersList
              .whereType<Map>()
              .map((item) => OrderListModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        
        // 날짜순 내림차순 정렬 (최신순)
        allOrders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
        
        setState(() {
          _allOrders = allOrders;
          _calculateStatusCounts();
          _applyFilter();
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
  
  /// 상태별 개수 계산
  void _calculateStatusCounts() {
    // 주문: odStatus == '주문'
    _orderCount = _allOrders.where((o) => o.odStatus == '주문').length;
    // 입금: odStatus == '입금'
    _paymentCount = _allOrders.where((o) => o.odStatus == '입금').length;
    // 배송: odStatus == '배송' || odStatus == '준비'
    _deliveryCount = _allOrders.where((o) => o.odStatus == '배송' || o.odStatus == '준비').length;
    // 완료: odStatus == '완료'
    _completeCount = _allOrders.where((o) => o.odStatus == '완료').length;
    
    // 취소/반품/교환 개수 (odStatus 기반으로 판단)
    _cancelCount = _allOrders.where((o) => o.odStatus.contains('cancel') || o.odStatus.contains('취소')).length;
    _returnCount = _allOrders.where((o) => o.odStatus.contains('return') || o.odStatus.contains('반품')).length;
    _exchangeCount = _allOrders.where((o) => o.odStatus.contains('exchange') || o.odStatus.contains('교환')).length;
  }
  
  /// 필터 적용
  void _applyFilter() {
    if (_selectedStatus == null) {
      // 전체 표시 (내림차순)
      _displayedOrders = List.from(_allOrders);
    } else {
      // 선택된 상태만 필터링 (odStatus 기반)
      _displayedOrders = _allOrders.where((order) {
        switch (_selectedStatus) {
          case 'order':
            return order.odStatus == '주문';
          case 'payment':
            return order.odStatus == '입금';
          case 'delivering':
            return order.odStatus == '배송' || order.odStatus == '준비';
          case 'finish':
            return order.odStatus == '완료';
          case 'cancel':
            return order.odStatus.contains('cancel') || order.odStatus.contains('취소');
          case 'return':
            return order.odStatus.contains('return') || order.odStatus.contains('반품');
          case 'exchange':
            return order.odStatus.contains('exchange') || order.odStatus.contains('교환');
          default:
            return true;
        }
      }).toList();
    }
  }
  
  /// 상태 필터 선택
  void _selectStatus(String? status) {
    setState(() {
      _selectedStatus = status;
      _applyFilter();
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: GestureDetector(
            onTap: () => _selectStatus(null),
            child: const Text(
              '주문내역',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            // 상태 카드
            _buildStatusCard(),
            
            // 주문 목록
            Expanded(
              child: _buildOrderList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태 카드 위젯
  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
        children: [
          // 주문 상태 흐름
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem('주문', _orderCount, 'order'),
              const Text('>', style: TextStyle(color: Colors.grey)),
              _buildStatusItem('입금', _paymentCount, 'payment'),
              const Text('>', style: TextStyle(color: Colors.grey)),
              _buildStatusItem('배송', _deliveryCount, 'delivering'),
              const Text('>', style: TextStyle(color: Colors.grey)),
              _buildStatusItem('완료', _completeCount, 'finish'),
            ],
          ),
          const SizedBox(height: 16),
          // 취소/반품/교환 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton('취소', _cancelCount, 'cancel'),
              _buildActionButton('반품', _returnCount, 'return'),
              _buildActionButton('교환', _exchangeCount, 'exchange'),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 상태 항목 위젯
  Widget _buildStatusItem(String label, int count, String? status) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => _selectStatus(status),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? const Color(0xFFFF4081) : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFFFF4081) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 액션 버튼 위젯 (취소/반품/교환)
  Widget _buildActionButton(String label, int count, String status) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectStatus(status),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF4081) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  /// 주문 목록 위젯
  Widget _buildOrderList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(
        color: Color(0xFFFF4081),
      ));
    }

    if (_displayedOrders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFFFF4081),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 주문 리스트 (padding 적용)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = _displayedOrders[index];
                  return _buildOrderCard(order);
                },
                childCount: _displayedOrders.length,
              ),
            ),
          ),
          
          // Footer  
          const SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 300),
                AppFooter(),
              ],
            ),
          ),
        ],
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
            onTap: () => _navigateToOrderDetail(order.odId),
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
                    // 결제완료: 예약 시간 변경 버튼 + 취소하기
                    if (order.displayStatus == '결제완료') ...[
                      // 모든 결제완료 주문에 시간 변경 버튼 표시
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildOrderActionButton(
                          '시간 변경',
                          color: Colors.blue,
                          onPressed: () => _changeReservationTimeFromList(order.odId),
                        ),
                      ),
                      _buildOrderActionButton(
                        '취소하기',
                        color: Colors.red,
                        onPressed: () => _cancelOrder(order.odId),
                      ),
                    ],
                    // 배송준비중: 취소하기만
                    if (order.displayStatus == '배송준비중')
                      _buildOrderActionButton(
                        '취소하기',
                        color: Colors.red,
                        onPressed: () => _cancelOrder(order.odId),
                      ),
                    // 배송중: 배송조회만
                    if (order.displayStatus == '배송중')
                      _buildOrderActionButton(
                        '배송조회',
                        onPressed: () =>
                            _trackDelivery(order.odId),
                      ),
                    // 배송완료: 배송확정 + 리뷰쓰기
                    if (order.displayStatus == '배송완료') ...[
                      _buildOrderActionButton(
                        '배송확정',
                        color: const Color(0xFFFF4081),
                        onPressed: () => _confirmPurchase(order.odId),
                      ),
                      const SizedBox(width: 8),
                      _buildOrderActionButton(
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

  /// 주문 카드 액션 버튼 위젯
  Widget _buildOrderActionButton(
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
  Widget _buildEmptyState() {
    final statusText = _selectedStatus == null 
        ? '주문' 
        : _getStatusText(_selectedStatus!);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '$statusText 내역이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 300),
          const AppFooter(),
        ],
      ),
    );
  }
  
  /// 상태 텍스트 가져오기
  String _getStatusText(String status) {
    switch (status) {
      case 'payment':
        return '입금';
      case 'delivering':
        return '배송';
      case 'finish':
        return '완료';
      case 'cancel':
        return '취소';
      case 'return':
        return '반품';
      case 'exchange':
        return '교환';
      default:
        return '주문';
    }
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
  Future<void> _cancelOrder(String odId) async {
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
  Future<void> _trackDelivery(String odId) async {
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
  Future<void> _confirmPurchase(String odId) async {
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
  Future<void> _writeReview(String odId) async {
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

  /// 예약 정보 확인 (주문 상세 조회)
  Future<Map<String, dynamic>> _checkReservationInfo(String odId) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return {'hasReservation': false};
      }

      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );

      // 404 에러나 실패한 경우 조용히 false 반환 (에러 로그는 서비스에서 처리)
      if (result['success'] != true) {
        return {'hasReservation': false};
      }

      final orderDetail = result['order'] as OrderDetailModel;
      final hasReservation = orderDetail.reservationDate != null && 
                            orderDetail.reservationTime != null;
      
      return {
        'hasReservation': hasReservation,
        'reservationDate': orderDetail.reservationDate,
        'reservationTime': orderDetail.reservationTime,
      };
    } catch (e) {
      // 에러 발생 시 조용히 false 반환 (콘솔 에러는 이미 출력됨)
      return {'hasReservation': false};
    }
  }

  /// 예약 시간 변경 (주문 목록에서 호출 - 예약 정보 확인 후 화면 이동)
  Future<void> _changeReservationTimeFromList(String odId) async {
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

      // 주문 상세 조회하여 예약 정보 확인
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );

      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final orderDetail = result['order'] as OrderDetailModel;

      // 예약 정보 확인
      if (orderDetail.reservationDate == null || orderDetail.reservationTime == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('예약 정보가 없는 주문입니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 예약 시간 변경 화면으로 이동
      final changeResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReservationTimeChangeScreen(
            orderId: odId,
            currentDate: orderDetail.reservationDate!,
            currentTime: orderDetail.reservationTime!,
          ),
        ),
      );

      // 예약 시간이 변경되었으면 해당 주문 상세 페이지로 이동
      if (changeResult == true && mounted) {
        // 주문 목록 새로고침
        _loadOrders();
        
        // 주문 상세 페이지로 이동 (새로고침된 데이터로)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryDetailScreen(orderNumber: odId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 시간 변경 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 예약 시간 변경 (예약 정보를 이미 알고 있는 경우)
  Future<void> _changeReservationTime(String odId, String currentDate, String currentTime) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReservationTimeChangeScreen(
          orderId: odId,
          currentDate: currentDate,
          currentTime: currentTime,
        ),
      ),
    );

    // 예약 시간이 변경되었으면 주문 목록 새로고침
    if (result == true && mounted) {
      _loadOrders();
    }
  }
}

