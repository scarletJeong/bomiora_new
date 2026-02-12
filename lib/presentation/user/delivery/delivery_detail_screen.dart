import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../../core/utils/image_url_helper.dart';
import 'reservation_time_change_screen.dart';

/// 주문 상세 화면
class DeliveryDetailScreen extends StatefulWidget {
  final String orderNumber;

  const DeliveryDetailScreen({
    super.key,
    required this.orderNumber,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  OrderDetailModel? _orderDetail;
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

    try {
      // 현재 로그인된 사용자 ID 가져오기
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // API 호출 (orderNumber는 이미 String이므로 그대로 사용)
      final result = await OrderService.getOrderDetail(
        odId: widget.orderNumber,
        mbId: user.id,
      );

      if (result['success'] == true) {
        setState(() {
          _orderDetail = result['order'] as OrderDetailModel;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '주문 정보를 불러올 수 없습니다.')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ 주문 상세 로드 에러: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문 정보를 불러오는 중 오류가 발생했습니다.')),
        );
      }
    }
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 주문 상태
          _buildOrderStatus(),
          const SizedBox(height: 8),

          // 취소 정보 (취소/반품인 경우만)
          if (_orderDetail!.displayStatus == '취소/반품')
            ...[
              _buildCancelInfo(),
              const SizedBox(height: 8),
            ],

          // 배송 정보
          _buildDeliveryInfo(),
          const SizedBox(height: 8),

          // 주문 상품 정보 (예약 정보 포함)
          _buildProductInfo(),
          const SizedBox(height: 8),

          // 결제 정보
          _buildPaymentInfo(),
          const SizedBox(height: 8),

          // 주문자 정보
          _buildOrdererInfo(),
          const SizedBox(height: 80), // 하단 버튼 공간
          
          const SizedBox(height: 300),
          
          // Footer  
          const AppFooter(),
        ],
      ),
    );
  }

  /// 주문 상태 섹션
  Widget _buildOrderStatus() {
    final status = _orderDetail!.displayStatus;
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
                _orderDetail!.orderDate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 배송 단계 인디케이터
          _buildDeliveryStepIndicator(status),
        ],
      ),
    );
  }

  /// 배송 단계 인디케이터
  Widget _buildDeliveryStepIndicator(String currentStatus) {
    final steps = ['결제완료', '준비중', '배송중', '배송완료'];
    
    // 취소/반품 상태인 경우 별도 표시
    if (currentStatus == '취소/반품') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          currentStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }
    
    // 현재 단계 인덱스 찾기
    int currentStepIndex = 0;
    if (currentStatus == '결제완료') currentStepIndex = 0;
    else if (currentStatus == '배송준비중') currentStepIndex = 1;
    else if (currentStatus == '배송중') currentStepIndex = 2;
    else if (currentStatus == '배송완료') currentStepIndex = 3;
    
    return Column(
      children: [
        // 스텝 바
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isEven) {
              // 스텝 원
              final stepIndex = index ~/ 2;
              final isActive = stepIndex <= currentStepIndex;
              final isCurrent = stepIndex == currentStepIndex;
              
               return Container(
                 width: 32,
                 height: 32,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: isCurrent
                       ? Colors.yellow[700]  // 현재 단계: 노란색
                       : isActive
                           ? Colors.green  // 완료된 단계: 초록색
                           : Colors.grey[300],  // 미완료 단계: 회색
                 ),
                 child: Center(
                   child: isActive && !isCurrent
                       ? const Icon(
                           Icons.check,
                           color: Colors.white,
                           size: 16,
                         )
                       : Text(
                           '${stepIndex + 1}',
                           style: TextStyle(
                             color: isCurrent || isActive
                                 ? Colors.white
                                 : Colors.grey[600],
                             fontWeight: FontWeight.bold,
                             fontSize: 14,
                           ),
                         ),
                 ),
               );
            } else {
              // 연결선
              final stepIndex = index ~/ 2;
              final isActive = stepIndex < currentStepIndex;
              
              return Expanded(
                child: Container(
                  height: 3,
                  color: isActive
                      ? Colors.green  // 완료된 연결선: 초록색
                      : Colors.grey[300],  // 미완료 연결선: 회색
                ),
              );
            }
          }),
        ),
        const SizedBox(height: 12),
        
        // 스텝 라벨
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (index) {
            final isActive = index <= currentStepIndex;
            final isCurrent = index == currentStepIndex;
            
             return SizedBox(
               width: 32,
               child: Text(
                 steps[index],
                 textAlign: TextAlign.center,
                 style: TextStyle(
                   fontSize: 10,
                   fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                   color: isCurrent
                       ? Colors.yellow[700]  // 현재 단계 라벨: 노란색
                       : isActive
                           ? Colors.green  // 완료된 단계 라벨: 초록색
                           : Colors.grey[600],  // 미완료 단계 라벨: 회색
                 ),
               ),
             );
          }),
        ),
      ],
    );
  }

  /// 취소 정보 섹션
  Widget _buildCancelInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.red[700],
              ),
              const SizedBox(width: 8),
              Text(
                '취소 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_orderDetail!.cancelType != null)
            _buildInfoRow(
              '취소 유형',
              _getCancelTypeDisplay(_orderDetail!.cancelType!),
              valueColor: Colors.red[700],
            ),
          if (_orderDetail!.cancelType != null && _orderDetail!.cancelReason != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              '취소 사유',
              _orderDetail!.cancelReason!,
              valueColor: Colors.red[700],
            ),
          ],
        ],
      ),
    );
  }
  
  /// 취소 유형 표시 텍스트
  String _getCancelTypeDisplay(String cancelType) {
    switch (cancelType) {
      case '고객직접':
        return '고객 직접 취소';
      case '시스템자동':
        return '시스템 자동 취소';
      case '관리자':
        return '관리자 취소';
      default:
        return cancelType;
    }
  }

  /// 예약 정보 섹션 (주문 상품 섹션 내부용)
  Widget _buildReservationInfoInProductSection() {
    final isPaymentCompleted = _orderDetail!.displayStatus == '결제완료';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                const Text(
                  '예약 정보',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          '예약 날짜',
          _formatReservationDate(_orderDetail!.reservationDate!),
        ),
        const SizedBox(height: 8),
        // 예약 시간 행 (텍스트 아래 버튼 가운데 정렬)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                '예약 시간',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 예약 시간 텍스트
                  Text(
                    _orderDetail!.reservationTime!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  // 결제 완료 상태에서만 예약 시간 변경 버튼 표시 (가운데 정렬)
                  if (isPaymentCompleted) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: _buildReservationTimeChangeButton(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 예약 시간 변경 버튼 (목록과 동일한 스타일)
  Widget _buildReservationTimeChangeButton() {
    return OutlinedButton(
      onPressed: _showReservationTimeChangeDialog,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        minimumSize: Size.zero,
      ),
      child: const Text(
        '시간 변경',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.blue,
        ),
      ),
    );
  }

  /// 예약 날짜 포맷팅
  String _formatReservationDate(String dateStr) {
    try {
      // ISO 8601 형식 또는 다른 형식 파싱
      DateTime date;
      if (dateStr.contains('T')) {
        date = DateTime.parse(dateStr);
      } else if (dateStr.contains('-')) {
        date = DateTime.parse(dateStr);
      } else {
        // 다른 형식 처리
        return dateStr;
      }
      
      return '${date.year}년 ${date.month}월 ${date.day}일';
    } catch (e) {
      return dateStr;
    }
  }

  /// 예약 시간 변경 다이얼로그 표시
  Future<void> _showReservationTimeChangeDialog() async {
    if (_orderDetail == null) {
      print('❌ [예약 시간 변경] 주문 상세 정보가 없습니다.');
      return;
    }
    
    if (_orderDetail!.reservationDate == null || _orderDetail!.reservationTime == null) {
      print('❌ [예약 시간 변경] 예약 정보가 없습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예약 정보가 없습니다.')),
      );
      return;
    }
    
    print('📅 [예약 시간 변경] 시작');
    print('  - orderId (from _orderDetail): ${_orderDetail!.odId}');
    print('  - orderNumber (from widget): ${widget.orderNumber}');
    print('  - currentDate: ${_orderDetail!.reservationDate}');
    print('  - currentTime: ${_orderDetail!.reservationTime}');
    
    // odId가 손상되었을 수 있으므로 widget.orderNumber를 우선 사용
    final orderIdToUse = widget.orderNumber.isNotEmpty ? widget.orderNumber : _orderDetail!.odId;
    print('  - orderId (최종 사용): $orderIdToUse');
    
    // 예약 시간 변경 화면으로 이동
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReservationTimeChangeScreen(
          orderId: orderIdToUse,
          currentDate: _orderDetail!.reservationDate!,
          currentTime: _orderDetail!.reservationTime!,
        ),
      ),
    );

    print('📅 [예약 시간 변경] 결과: $result');

    // 예약 시간이 변경되었으면 주문 상세 다시 로드
    if (result == true && mounted) {
      print('📅 [예약 시간 변경] 주문 상세 새로고침');
      _loadOrderDetail();
    }
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
          _buildInfoRow('받는 사람', _orderDetail!.recipientName),
          const SizedBox(height: 12),
          _buildInfoRow('연락처', _orderDetail!.recipientPhone),
          const SizedBox(height: 12),
          _buildInfoRow(
            '배송지',
            '${_orderDetail!.recipientAddress}\n${_orderDetail!.recipientAddressDetail}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow('배송 요청사항', _orderDetail!.deliveryMessage ?? '-'),
          // 택배사 정보가 있으면 표시
          if (_orderDetail!.deliveryCompany != null && 
              _orderDetail!.deliveryCompany!.isNotEmpty) ...[
            const Divider(height: 32),
            _buildInfoRow('택배사', _orderDetail!.deliveryCompany!),
            const SizedBox(height: 12),
            // 운송장번호가 있고, 취소/반품이 아닐 때만 배송조회 버튼 표시
            if (_orderDetail!.trackingNumber != null && 
                _orderDetail!.trackingNumber!.isNotEmpty &&
                _orderDetail!.displayStatus != '취소/반품')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      '운송장번호',
                      _orderDetail!.trackingNumber!,
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
              )
            else if (_orderDetail!.trackingNumber != null && 
                     _orderDetail!.trackingNumber!.isNotEmpty)
              _buildInfoRow('운송장번호', _orderDetail!.trackingNumber!),
          ],
        ],
      ),
    );
  }

  /// 주문 상품 정보 섹션
  Widget _buildProductInfo() {
    final products = _orderDetail!.products;
    final hasReservation = _orderDetail!.reservationDate != null && 
                          _orderDetail!.reservationTime != null;

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
          
          // 예약 정보 (예약이 있는 경우만)
          if (hasReservation) ...[
            const Divider(height: 32),
            _buildReservationInfoInProductSection(),
          ],
        ],
      ),
    );
  }

  /// 상품 카드
  Widget _buildProductCard(OrderItem product) {
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
          _buildProductImage(product),
          const SizedBox(width: 12),

          // 상품 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.itName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (product.ctOption != null && product.ctOption!.isNotEmpty)
                  Text(
                    product.ctOption!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${product.ctQty}개 · ${_formatPrice(product.totalPrice)}원',
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
            '${_formatPrice(_orderDetail!.productPrice)}원',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            '배송비',
            '${_formatPrice(_orderDetail!.deliveryFee)}원',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            '할인금액',
            '-${_formatPrice(_orderDetail!.discountAmount)}원',
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
                '${_formatPrice(_orderDetail!.totalPrice)}원',
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
            _orderDetail!.paymentMethod + (_orderDetail!.paymentMethodDetail ?? ''),
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
          _buildInfoRow('이름', _orderDetail!.ordererName),
          const SizedBox(height: 12),
          _buildInfoRow('연락처', _orderDetail!.ordererPhone),
          const SizedBox(height: 12),
          _buildInfoRow('이메일', _orderDetail!.ordererEmail),
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
  Future<void> _trackDelivery() async {
    if (_orderDetail == null) return;
    
    final companyName = _orderDetail!.deliveryCompany;
    final trackingNumber = _orderDetail!.trackingNumber;
    
    // 택배사와 운송장번호 확인
    if (companyName == null || companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('택배사 정보가 없습니다.')),
      );
      return;
    }
    
    if (trackingNumber == null || trackingNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운송장번호가 없습니다.')),
      );
      return;
    }
    
    // 지원하는 택배사인지 확인
    if (!DeliveryTracker.isSupported(companyName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$companyName은(는) 지원하지 않는 택배사입니다.')),
      );
      return;
    }
    
    // 배송 조회 페이지 열기
    final success = await DeliveryTracker.openTrackingPage(companyName, trackingNumber);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배송 조회 페이지를 열 수 없습니다.')),
      );
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
  Widget _buildProductImage(OrderItem product) {
    // 이미지 URL 정규화
    final normalizedUrl = product.imageUrl != null && product.imageUrl!.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(product.imageUrl, product.itId)
        : null;
    
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: normalizedUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                normalizedUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    size: 32,
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
              size: 32,
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

