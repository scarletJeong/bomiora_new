import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar.dart';
import 'widgets/order_flow_dialogs.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../utils/delivery_tracker.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/price_formatter.dart';
import 'widgets/reservation_time_change_popup.dart';
import '../review/review_write_screen.dart';
import '../review/review_write_general_screen.dart';
import 'widgets/delivery_address_change_popup.dart';

enum _DetailOrderActionStyle { filledPink, outlinedPink, mutedGray }

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

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kMutedLabel = Color(0xFF898383);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kBarBorder = Color(0xFFF1F5F9);

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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.grey[50],
        appBar: const HealthAppBar(title: '주문 상세'),
        // MobileAppLayoutWrapper 내부에 이미 Scaffold가 있어 여기서 또 Scaffold를 두면
        // 일부 환경에서 터치/히트 테스트가 어긋날 수 있음 → Material만 사용
        child: Material(
          color: Colors.grey[50],
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orderDetail == null
                  ? _buildErrorState()
                  : _buildOrderDetail(),
        ),
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
    final order = _orderDetail!;
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            _buildDetailProgressCard(order),
            const SizedBox(height: 20),
            _buildDetailOrderProductSection(order),
            const SizedBox(height: 10),
            _buildDetailSectionTitleRow('결제', '정보'),
            const SizedBox(height: 10),
            _buildDetailPaymentCard(order),
            const SizedBox(height: 10),
            _buildDetailSectionTitleRow('할인', '정보'),
            const SizedBox(height: 10),
            _buildDetailDiscountCard(order),
            const SizedBox(height: 10),
            _buildDetailSectionTitleRow('예약', '정보'),
            const SizedBox(height: 10),
            _buildDetailReservationCard(order),
            const SizedBox(height: 10),
            _buildDetailSectionTitleRow('배송', '정보'),
            const SizedBox(height: 10),
            _buildDetailDeliveryCard(order),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _detailProgressStep(OrderDetailModel order) {
    if (_isCompletedStageDetail(order)) return 3;
    if (_isDeliveringStageDetail(order)) return 2;
    if (_isPreparingStageDetail(order)) return 1;
    // 결제 완료 후에는 단계바 상 '배송준비중' 구간으로 진행
    if (order.displayStatus == '결제완료') return 1;
    if (_isPaymentStageDetail(order)) return 0;
    return 0;
  }

  Widget _buildDetailProgressCard(OrderDetailModel order) {
    const labels = ['결제대기중', '배송준비중', '배송중', '배송완료'];
    final step = _detailProgressStep(order).clamp(0, 3);
    final statusTitle = labels[step];
    final fill = (step + 1) / 4.0;

    return Container(
      height: 146,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBarBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(21, 18, 21, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              statusTitle,
              style: const TextStyle(
                color: _kPink,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
                height: 1.43,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '주문일자: ${order.orderDate}',
              style: const TextStyle(
                color: _kInk,
                fontSize: 10,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '주문번호: ${order.odId}',
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.odId));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.copy, size: 14, color: _kMuted),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 8,
                    color: const Color(0xFFF6F6F6),
                  ),
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kPink,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (i) {
                final active = i == step;
                return Expanded(
                  child: Opacity(
                    opacity: active ? 1.0 : 0.8,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? _kPink : _kMuted,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSectionTitleRow(String bold, String light) {
    return Row(
      children: [
        Container(
          width: 1,
          height: 16,
          color: _kInk,
        ),
        const SizedBox(width: 8),
        Text(
          bold,
          style: const TextStyle(
            color: _kInk,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -1.44,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          light,
          style: const TextStyle(
            color: _kInk,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            letterSpacing: -1.76,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailOrderProductSection(OrderDetailModel order) {
    final statusActions = _buildStatusActionButtons(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSectionTitleRow('주문상품', '정보'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorder),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...order.products.asMap().entries.expand((entry) {
                final index = entry.key;
                final product = entry.value;
                final optionText = product.ctOption != null && product.ctOption!.isNotEmpty
                    ? ' /${product.ctOption}'
                    : '';

                return <Widget>[
                  if (index > 0) const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailProductThumb(product),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.itName,
                              style: const TextStyle(
                                color: _kInk,
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.26,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '수량: ${product.ctQty}$optionText',
                              style: const TextStyle(
                                color: Color(0xFF898383),
                                fontSize: 10,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${PriceFormatter.format(product.totalPrice)}원',
                              style: const TextStyle(
                                color: _kInk,
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ];
              }),
              if (order.products.isNotEmpty) const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.deliveryFee > 0) ...[
                      Text(
                        '(배송비: ${PriceFormatter.format(order.deliveryFee)}원)',
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 12,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      '총 ${PriceFormatter.format(order.totalPrice)}원',
                      style: const TextStyle(
                        color: _kInk,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusActions != null) ...[
                const SizedBox(height: 20),
                statusActions,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailProductThumb(OrderItem product) {
    final normalizedUrl = product.imageUrl != null && product.imageUrl!.isNotEmpty
        ? ImageUrlHelper.normalizeThumbnailUrl(product.imageUrl, product.itId)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 80,
        height: 80,
        child: normalizedUrl != null
            ? Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: Icon(Icons.image_outlined, color: Colors.grey[400]),
                ),
              )
            : Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: Icon(Icons.image_outlined, color: Colors.grey[400]),
              ),
      ),
    );
  }

  bool _isVirtualAccountPayment(OrderDetailModel order) {
    return order.paymentMethod.contains('가상');
  }

  Widget _buildDetailPaymentCard(OrderDetailModel order) {
    final rawBank =
        (order.odBankAccount ?? order.paymentMethodDetail ?? '').trim();

    if (_isVirtualAccountPayment(order) && rawBank.contains('/')) {
      final parts = rawBank.split('/');
      final bankName = parts[0].trim();
      final accountNo = parts.length >= 2 ? parts[1].trim() : '';
      final deadlineToken = parts.length >= 3 ? parts[2].trim() : '';
      final deadlineLabel =
          DateDisplayFormatter.formatBankDeadlineCompact14(deadlineToken);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: _kBorder),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.paymentMethod.isEmpty ? '결제수단' : order.paymentMethod,
              style: const TextStyle(
                color: Color(0xFF898383),
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),
            _detailVirtualBankRow(
              bankName: bankName.isEmpty ? '-' : bankName,
              accountNo: accountNo.isEmpty ? '-' : accountNo,
            ),
            const SizedBox(height: 10),
            _detailKvLine('입금기한 :', deadlineLabel),
          ],
        ),
      );
    }

    final detail = order.paymentMethodDetail ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.paymentMethod.isEmpty ? '결제수단' : order.paymentMethod,
            style: const TextStyle(
              color: Color(0xFF898383),
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 20),
          _detailKvLine('결제카드 :', detail.isEmpty ? '-' : detail),
          const SizedBox(height: 10),
          _detailKvLine(
            '결제일 :',
            DateDisplayFormatter.formatDotDateTimeToKoreanLong(order.orderDate),
          ),
          const SizedBox(height: 10),
          _detailKvLine('총 결제 금액 :', '${PriceFormatter.format(order.totalPrice)}원'),
        ],
      ),
    );
  }

  static const TextStyle _bankLineTextStyle = TextStyle(
    fontSize: 12,
    fontFamily: 'Gmarket Sans TTF',
    letterSpacing: -0.6,
    height: 1.25,
  );

  Widget _detailVirtualBankRow({
    required String bankName,
    required String accountNo,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '입금 은행 :',
          style: _bankLineTextStyle.copyWith(
            color: _kMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                '$bankName $accountNo',
                style: _bankLineTextStyle.copyWith(
                  color: _kInk,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (accountNo.isNotEmpty && accountNo != '-')
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: accountNo));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3.5,
                      ),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 0.5,
                            color: Color(0xFFD2D2D2),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '복사',
                            style: TextStyle(
                              color: Color(0xFF898686),
                              fontSize: 8,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailKvLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kMuted,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _kInk,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDiscountCard(OrderDetailModel order) {
    var coupon = order.couponDiscount;
    var point = order.pointDiscount;
    if (coupon == 0 && point == 0 && order.discountAmount > 0) {
      coupon = order.discountAmount;
    }
    final totalDisc = coupon + point;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailKvLine(
            '쿠폰할인 :',
            coupon > 0 ? '${PriceFormatter.format(coupon)}원' : '0원',
          ),
          const SizedBox(height: 10),
          _detailKvLine(
            '포인트할인 :',
            point > 0 ? '${PriceFormatter.format(point)}원' : '0원',
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '총 할인 금액 :',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${PriceFormatter.format(totalDisc)}원',
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailReservationCard(OrderDetailModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailKvLine('담당 한의사 :', '정대진 원장'),
          const SizedBox(height: 10),
          _detailKvLine(
            '예약 일자 :',
            DateDisplayFormatter.formatReservationDateWithWeekday(order.reservationDate),
          ),
          const SizedBox(height: 10),
          _detailKvLine('예약 시간 :', order.reservationTime ?? '-'),
        ],
      ),
    );
  }

  Widget _buildDetailDeliveryCard(OrderDetailModel order) {
    final addr = '${order.recipientAddress} ${order.recipientAddressDetail}'.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailKvLine('이름 :', order.recipientName),
          const SizedBox(height: 10),
          _detailKvLine('연락처 :', order.recipientPhone),
          const SizedBox(height: 10),
          _detailKvLine('주소 :', addr.isEmpty ? '-' : addr),
          const SizedBox(height: 10),
          const Text(
            '배송 요청사항 :',
            style: TextStyle(
              color: _kMutedLabel,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            order.deliveryMessage?.isNotEmpty == true ? order.deliveryMessage! : '-',
            style: const TextStyle(
              color: _kInk,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusActionButtons(OrderDetailModel order) {
    final isPrescription = order.isPrescriptionOrder;

    if (_isPaymentStageDetail(order) || _isPreparingStageDetail(order)) {
      if (isPrescription) {
        return Row(
          children: [
            Expanded(
              child: _detailOrderActionFilledPink(
                label: '배송지변경',
                onTap: _changeDeliveryAddress,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailOrderActionOutlinedPink(
                label: '예약시간변경',
                onTap: _showReservationTimeChangeDialog,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailOrderActionChip(
                label: '주문취소',
                style: _DetailOrderActionStyle.mutedGray,
                onTap: _cancelOrder,
              ),
            ),
          ],
        );
      }

      // 일반상품: 배송지변경 + 주문취소
      return Row(
        children: [
          Expanded(
            child: _detailOrderActionFilledPink(
              label: '배송지변경',
              onTap: _changeDeliveryAddress,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _detailOrderActionChip(
              label: '주문취소',
              style: _DetailOrderActionStyle.mutedGray,
              onTap: _cancelOrder,
            ),
          ),
        ],
      );
    }

    if (_isDeliveringStageDetail(order) || _isCompletedStageDetail(order)) {
      return Row(
        children: [
          Expanded(
            child: _detailOrderActionChip(
              label: '수령확인',
              style: _DetailOrderActionStyle.filledPink,
              onTap: _confirmPurchase,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _detailOrderActionChip(
              label: '배송조회',
              style: _DetailOrderActionStyle.outlinedPink,
              onTap: _trackDelivery,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _detailOrderActionChip(
              label: '리뷰쓰기',
              style: _DetailOrderActionStyle.mutedGray,
              onTap: _writeReviewFromDetail,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _detailOrderActionChip(
              label: '교환/환불',
              style: _DetailOrderActionStyle.mutedGray,
              onTap: null,
            ),
          ),
        ],
      );
    }

    return null;
  }

  /// 주문 상단 액션 — 맨 앞(핑크 채움)
  Widget _detailOrderActionFilledPink({
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: enabled ? _kPink : _kPink.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.85),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 주문 상단 액션 — 두 번째(핑크 테두리)
  Widget _detailOrderActionOutlinedPink({
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: enabled ? _kPink : _kPink.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: enabled ? _kPink : _kPink.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailOrderActionChip({
    required String label,
    required _DetailOrderActionStyle style,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            color: switch (style) {
              _DetailOrderActionStyle.filledPink => Colors.white,
              _DetailOrderActionStyle.outlinedPink =>
                enabled ? _kPink : _kPink.withValues(alpha: 0.45),
              _DetailOrderActionStyle.mutedGray => _kMuted,
            },
          ),
        ),
      ),
    );

    return Material(
      color: switch (style) {
        _DetailOrderActionStyle.filledPink => enabled ? _kPink : _kPink.withValues(alpha: 0.45),
        _DetailOrderActionStyle.outlinedPink => Colors.white,
        _DetailOrderActionStyle.mutedGray => const Color(0x7FD2D2D2),
      },
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        canRequestFocus: enabled,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: style == _DetailOrderActionStyle.outlinedPink
                ? Border.all(
                    width: 1,
                    color: enabled ? _kPink : _kPink.withValues(alpha: 0.35),
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  bool _isPaymentStageDetail(OrderDetailModel order) {
    return order.displayStatus == '결제완료' ||
        order.displayStatus == '결제대기중' ||
        order.odStatus == '주문';
  }

  bool _isPreparingStageDetail(OrderDetailModel order) {
    return order.displayStatus == '배송준비중' ||
        order.odStatus == '입금' ||
        order.odStatus == '준비';
  }

  bool _isDeliveringStageDetail(OrderDetailModel order) {
    return order.displayStatus == '배송중' || order.odStatus == '배송';
  }

  bool _isCompletedStageDetail(OrderDetailModel order) {
    return order.displayStatus == '배송완료' || order.odStatus == '완료';
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
          DateDisplayFormatter.formatKoreanDateFromString(_orderDetail!.reservationDate!),
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

  /// 예약 시간 변경 다이얼로그 표시
  Future<void> _showReservationTimeChangeDialog() async {
    if (_orderDetail == null) return;
    
    if (_orderDetail!.reservationDate == null || _orderDetail!.reservationTime == null) {
      return;
    }
    
    // odId가 손상되었을 수 있으므로 widget.orderNumber를 우선 사용
    final orderIdToUse = widget.orderNumber.isNotEmpty ? widget.orderNumber : _orderDetail!.odId;
    
    // 예약 시간 변경 화면으로 이동
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '예약시간 변경',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            ReservationTimeChangePopup(
              orderId: orderIdToUse,
              currentDate: _orderDetail!.reservationDate!,
              currentTime: _orderDetail!.reservationTime!,
            ),
          ],
        );
      },
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
                  '${product.ctQty}개 · ${PriceFormatter.format(product.totalPrice)}원',
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
            '${PriceFormatter.format(_orderDetail!.productPrice)}원',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            '배송비',
            '${PriceFormatter.format(_orderDetail!.deliveryFee)}원',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            '할인금액',
            '-${PriceFormatter.format(_orderDetail!.discountAmount)}원',
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
                '${PriceFormatter.format(_orderDetail!.totalPrice)}원',
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

  Future<void> _cancelOrder() async {
    if (_orderDetail == null) return;
    final confirmed = await OrderFlowDialogs.showOrderCancelConfirm(context);
    if (confirmed != true) return;

    final user = await AuthService.getUser();
    if (user == null) return;

    final result = await OrderService.cancelOrder(
      odId: _orderDetail!.odId,
      mbId: user.id,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      await OrderFlowDialogs.showOrderCancelSuccess(context);
      if (mounted) _loadOrderDetail();
    }
  }

  Future<void> _confirmPurchase() async {
    if (_orderDetail == null) return;
    final confirmed = await OrderFlowDialogs.showReceiptConfirm(context);
    if (confirmed != true) return;

    final user = await AuthService.getUser();
    if (user == null) return;

    final result = await OrderService.confirmPurchase(
      odId: _orderDetail!.odId,
      mbId: user.id,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      _loadOrderDetail();
    }
  }

  Future<void> _changeDeliveryAddress() async {
    if (_orderDetail == null) return;
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '배송지 변경',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            DeliveryAddressChangePopup(orderId: _orderDetail!.odId),
          ],
        );
      },
    );
    if (result == true && mounted) {
      _loadOrderDetail();
    }
  }

  Future<void> _writeReviewFromDetail() async {
    if (_orderDetail == null) return;
    final isPrescription = _orderDetail!.isPrescriptionOrder;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isPrescription
            ? ReviewWriteScreen(orderDetail: _orderDetail!)
            : ReviewWriteGeneralScreen(orderDetail: _orderDetail!),
      ),
    );
    if (result == true && mounted) {
      _loadOrderDetail();
    }
  }

  /// 배송 조회
  Future<void> _trackDelivery() async {
    if (_orderDetail == null) return;
    
    final companyName = _orderDetail!.deliveryCompany;
    final trackingNumber = _orderDetail!.trackingNumber;
    
    // 택배사와 운송장번호 확인
    if (companyName == null || companyName.isEmpty) {
      return;
    }
    
    if (trackingNumber == null || trackingNumber.isEmpty) {
      return;
    }
    
    // 지원하는 택배사인지 확인
    if (!DeliveryTracker.isSupported(companyName)) {
      return;
    }
    
    // 배송 조회 페이지 열기
    await DeliveryTracker.openTrackingPage(companyName, trackingNumber);
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

}

