import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import 'order_detail_screen.dart';

/// 주문/배송 조회 화면
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '1개월'; // 선택된 기간

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                // TODO: 기간별 주문 조회 API 호출
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
    // TODO: 실제 API 데이터로 교체
    final mockOrders = _getMockOrders(status);

    if (mockOrders.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockOrders.length,
      itemBuilder: (context, index) {
        final order = mockOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  /// 주문 카드 위젯
  Widget _buildOrderCard(Map<String, dynamic> order) {
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
                  order['date'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '주문번호: ${order['orderNumber']}',
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
            onTap: () => _navigateToOrderDetail(order['orderNumber']),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품 이미지
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image: order['imageUrl'] != null
                          ? DecorationImage(
                              image: NetworkImage(order['imageUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: order['imageUrl'] == null
                        ? Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // 상품 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['productName'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (order['option'] != null)
                          Text(
                            order['option'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${order['quantity']}개 · ${_formatPrice(order['price'])}원',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
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
                    color: _getStatusColor(order['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order['status'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(order['status']),
                    ),
                  ),
                ),

                // 액션 버튼
                Row(
                  children: [
                    _buildActionButton(
                      '상세보기',
                      onPressed: () =>
                          _navigateToOrderDetail(order['orderNumber']),
                    ),
                    const SizedBox(width: 8),
                    if (order['status'] == '결제완료' ||
                        order['status'] == '배송준비중')
                      _buildActionButton(
                        '취소하기',
                        color: Colors.red,
                        onPressed: () => _cancelOrder(order['orderNumber']),
                      ),
                    if (order['status'] == '배송중')
                      _buildActionButton(
                        '배송조회',
                        onPressed: () =>
                            _trackDelivery(order['orderNumber']),
                      ),
                    if (order['status'] == '배송완료')
                      _buildActionButton(
                        '구매확정',
                        color: const Color(0xFFFF4081),
                        onPressed: () =>
                            _confirmPurchase(order['orderNumber']),
                      ),
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
        builder: (context) => OrderDetailScreen(orderNumber: orderNumber),
      ),
    );
  }

  /// 주문 취소
  void _cancelOrder(String orderNumber) {
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
            onPressed: () {
              // TODO: 주문 취소 API 호출
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('주문이 취소되었습니다.')),
              );
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
  void _trackDelivery(String orderNumber) {
    // TODO: 배송 조회 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배송 조회 기능 준비 중입니다.')),
    );
  }

  /// 구매 확정
  void _confirmPurchase(String orderNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구매 확정'),
        content: const Text('구매를 확정하시겠습니까?\n확정 후에는 교환/반품이 불가능합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 구매 확정 API 호출
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('구매가 확정되었습니다.')),
              );
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
      case '취소':
      case '반품':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 가격 포맷팅
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Mock 데이터 (테스트용)
  List<Map<String, dynamic>> _getMockOrders(String status) {
    // TODO: 실제 API로 교체
    final allOrders = [
      {
        'orderNumber': '20251110001',
        'date': '2025.11.10',
        'productName': '보미오라 다이어트환 [04단계] 스트롱',
        'option': '[04단계]스트롱_Strong / 3개월',
        'quantity': 1,
        'price': 450000,
        'status': '결제완료',
        'imageUrl': null,
      },
      {
        'orderNumber': '20251109002',
        'date': '2025.11.09',
        'productName': '보미오라 다이어트환 [03단계] 하드',
        'option': '[03단계]하드_Hard / 2개월',
        'quantity': 1,
        'price': 320000,
        'status': '배송준비중',
        'imageUrl': null,
      },
      {
        'orderNumber': '20251108003',
        'date': '2025.11.08',
        'productName': '보미오라 다이어트환 [02단계] 미디엄',
        'option': '[02단계]미디엄_Medium / 1개월',
        'quantity': 2,
        'price': 280000,
        'status': '배송중',
        'imageUrl': null,
      },
      {
        'orderNumber': '20251107004',
        'date': '2025.11.07',
        'productName': '보미오라 다이어트환 [01단계] 소프트',
        'option': '[01단계]소프트_Soft / 1개월',
        'quantity': 1,
        'price': 140000,
        'status': '배송완료',
        'imageUrl': null,
      },
    ];

    if (status == '전체') return allOrders;
    return allOrders.where((order) => order['status'] == status).toList();
  }
}

