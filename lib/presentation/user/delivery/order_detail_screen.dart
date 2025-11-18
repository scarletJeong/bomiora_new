import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

/// 주문 상세 화면
class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;

  const OrderDetailScreen({
    super.key,
    required this.orderNumber,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _orderDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
  }

  /// 주문 상세 조회
  Future<void> _loadOrderDetail() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: 실제 API 호출로 교체
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _orderDetail = _getMockOrderDetail();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            '주문 상세',
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
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _orderDetail == null
                ? _buildErrorState()
                : _buildOrderDetail(),
      ),
    );
  }

  /// 에러 상태
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '주문 정보를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrderDetail,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 주문 상세 내용
  Widget _buildOrderDetail() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주문 상태
          _buildOrderStatus(),
          const SizedBox(height: 8),

          // 배송 정보
          _buildDeliveryInfo(),
          const SizedBox(height: 8),

          // 주문 상품 정보
          _buildProductInfo(),
          const SizedBox(height: 8),

          // 결제 정보
          _buildPaymentInfo(),
          const SizedBox(height: 8),

          // 주문자 정보
          _buildOrdererInfo(),
          const SizedBox(height: 80), // 하단 버튼 공간
        ],
      ),
    );
  }

  /// 주문 상태 섹션
  Widget _buildOrderStatus() {
    final status = _orderDetail!['status'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주문번호',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Text(
                    widget.orderNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.orderNumber),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('주문번호가 복사되었습니다.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주문일시',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                _orderDetail!['orderDate'],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 배송 정보 섹션
  Widget _buildDeliveryInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '배송 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('받는 사람', _orderDetail!['recipientName']),
          const SizedBox(height: 12),
          _buildInfoRow('연락처', _orderDetail!['recipientPhone']),
          const SizedBox(height: 12),
          _buildInfoRow(
            '배송지',
            '${_orderDetail!['address']}\n${_orderDetail!['addressDetail']}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow('배송 요청사항', _orderDetail!['deliveryMessage'] ?? '-'),
          if (_orderDetail!['deliveryCompany'] != null) ...[
            const Divider(height: 32),
            _buildInfoRow('택배사', _orderDetail!['deliveryCompany']),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoRow(
                    '운송장번호',
                    _orderDetail!['trackingNumber'],
                  ),
                ),
                OutlinedButton(
                  onPressed: _trackDelivery,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: const BorderSide(color: Color(0xFFFF4081)),
                  ),
                  child: const Text(
                    '배송조회',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF4081),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 주문 상품 정보 섹션
  Widget _buildProductInfo() {
    final products = _orderDetail!['products'] as List<Map<String, dynamic>>;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문 상품',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...products.map((product) => _buildProductCard(product)),
        ],
      ),
    );
  }

  /// 상품 카드
  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품 이미지
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image,
              size: 32,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),

          // 상품 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (product['option'] != null)
                  Text(
                    product['option'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${product['quantity']}개 · ${_formatPrice(product['price'])}원',
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
    );
  }

  /// 결제 정보 섹션
  Widget _buildPaymentInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '결제 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            '상품금액',
            '${_formatPrice(_orderDetail!['productPrice'])}원',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            '배송비',
            '${_formatPrice(_orderDetail!['deliveryFee'])}원',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            '할인금액',
            '-${_formatPrice(_orderDetail!['discountAmount'])}원',
            valueColor: Colors.red,
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '총 결제금액',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_formatPrice(_orderDetail!['totalPrice'])}원',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF4081),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            '결제방법',
            _orderDetail!['paymentMethod'],
          ),
        ],
      ),
    );
  }

  /// 주문자 정보 섹션
  Widget _buildOrdererInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문자 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('이름', _orderDetail!['ordererName']),
          const SizedBox(height: 12),
          _buildInfoRow('연락처', _orderDetail!['ordererPhone']),
          const SizedBox(height: 12),
          _buildInfoRow('이메일', _orderDetail!['ordererEmail']),
        ],
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// 배송 조회
  void _trackDelivery() {
    // TODO: 배송 조회 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배송 조회 기능 준비 중입니다.')),
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
  Map<String, dynamic> _getMockOrderDetail() {
    // TODO: 실제 API로 교체
    return {
      'orderDate': '2025.11.10 14:30',
      'status': '배송중',
      'recipientName': '홍길동',
      'recipientPhone': '010-1234-5678',
      'address': '서울시 강남구 테헤란로 123',
      'addressDetail': '456호 (역삼동, 테헤란빌딩)',
      'deliveryMessage': '문 앞에 놓아주세요.',
      'deliveryCompany': 'CJ대한통운',
      'trackingNumber': '123456789012',
      'products': [
        {
          'name': '보미오라 다이어트환 [04단계] 스트롱',
          'option': '[04단계]스트롱_Strong / 3개월',
          'quantity': 1,
          'price': 450000,
        },
      ],
      'productPrice': 450000,
      'deliveryFee': 3000,
      'discountAmount': 0,
      'totalPrice': 453000,
      'paymentMethod': '신용카드',
      'ordererName': '홍길동',
      'ordererPhone': '010-1234-5678',
      'ordererEmail': 'hong@example.com',
    };
  }
}

