import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
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
import '../../health/health_common/health_responsive_scale.dart';

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
        final order = result['order'] as OrderDetailModel;
        debugPrint(
          '[OrderDetail] odId=${order.odId} '
          'od_app_no=${order.odAppNo} '
          'paymentMethod=${order.paymentMethod} '
          'paymentMethodDetail=${order.paymentMethodDetail} '
          'cardLine=${_isCardPayment(order) ? _formatCardPaymentLine(order) : '-'}',
        );
        setState(() {
          _orderDetail = order;
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
        appBar: const HealthAppBar(title: '주문 내역'),
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
            size: healthDp(context, 64),
            color: Colors.grey[400],
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '주문 정보를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: healthSp(context, 16),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: healthDp(context, 16)),
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
        padding: EdgeInsets.only(
          left: healthDp(context, 27),
          right: healthDp(context, 27),
          bottom: healthDp(context, 20),
        ),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: healthDp(context, 20)),
            _buildDetailProgressCard(order),
            SizedBox(height: healthDp(context, 20)),
            _buildDetailOrderProductSection(order),
            SizedBox(height: healthDp(context, 20)),
            _buildDetailPlainSectionTitle('결제 정보'),
            SizedBox(height: healthDp(context, 10)),
            _buildDetailPaymentCard(order),
            SizedBox(height: healthDp(context, 20)),
            _buildDetailPlainSectionTitle('할인 정보'),
            SizedBox(height: healthDp(context, 10)),
            _buildDetailDiscountCard(order),
            if (order.isPrescriptionOrder) ...[
              SizedBox(height: healthDp(context, 20)),
              _buildDetailPlainSectionTitle('예약 정보'),
              SizedBox(height: healthDp(context, 10)),
              _buildDetailReservationCard(order),
            ],
            SizedBox(height: healthDp(context, 20)),
            _buildDetailPlainSectionTitle('배송 정보'),
            SizedBox(height: healthDp(context, 10)),
            _buildDetailDeliveryCard(order),
            SizedBox(height: healthDp(context, 20)),
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
    // 현재 단계 라벨 **가운데**까지 채움 (구간 끝이 아님)
    final fill = (step + 0.5) / 4.0;

    return Container(
      constraints: BoxConstraints(minHeight: healthDp(context, 146)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBarBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
        shadows: [
          BoxShadow(
            color: const Color(0x0C000000),
            blurRadius: healthDp(context, 2),
            offset: Offset(0, healthDp(context, 1)),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 21),
          healthDp(context, 21),
          healthDp(context, 21),
          healthDp(context, 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              statusTitle,
              style: TextStyle(
                color: _kPink,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w700,
                height: 1.43,
              ),
            ),
            SizedBox(height: healthDp(context, 4)),
            Text(
              '주문일자: ${order.orderDate}',
              style: _detailMetaTextStyle(context),
            ),
            SizedBox(height: healthDp(context, 4)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '주문번호: ${order.odId}',
                    style: _detailMetaTextStyle(context),
                  ),
                ),
                Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: order.odId));
                      },
                      borderRadius: BorderRadius.circular(healthDp(context, 4)),
                      child: Padding(
                        padding: EdgeInsets.all(healthDp(context, 6)),
                        child: Icon(
                          Icons.copy,
                          size: healthDp(context, 14),
                          color: _kMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
            ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 9999)),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: healthDp(context, 8),
                    color: const Color(0xFFF6F6F6),
                  ),
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(
                      height: healthDp(context, 8),
                      decoration: BoxDecoration(
                        color: _kPink,
                        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: healthDp(context, 12)),
            Row(
              children: List.generate(4, (i) {
                final active = i == step;
                return Expanded(
                  child: Opacity(
                    opacity: active ? 1.0 : 0.8,
                    child: Text(
                      labels[i],
                      textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? _kPink : _kMuted,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.35,
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

  /// 섹션 제목 — 세로 막대 + 한 줄 텍스트 (예: 결제 정보)
  Widget _buildDetailPlainSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: healthDp(context, 1),
          height: healthDp(context, 16),
          color: _kInk,
        ),
        SizedBox(width: healthDp(context, 8)),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF1A1A1E),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: healthDp(context, -1.26),
          ),
        ),
      ],
    );
  }

  // 상세정보 섹션
  Widget _buildDetailOrderProductSection(OrderDetailModel order) {
    final statusActions = _buildStatusActionButtons(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailPlainSectionTitle('상세 정보'),
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 20)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _kBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
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
                  if (index > 0) SizedBox(height: healthDp(context, 16)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailProductThumb(product),
                      SizedBox(width: healthDp(context, 20)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.itName,
                              style: TextStyle(
                                color: _kInk,
                                fontSize: healthSp(context, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                letterSpacing: healthDp(context, -1.26),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: healthDp(context, 5)),
                            Text(
                              '수량: ${product.ctQty}$optionText',
                              style: TextStyle(
                                color: Color(0xFF898383),
                                fontSize: healthSp(context, 10),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: healthDp(context, 5)),
                            Text(
                              '${PriceFormatter.format(product.totalPrice)}원',
                              style: TextStyle(
                                color: _kInk,
                                fontSize: healthSp(context, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ];
              }),
              if (order.products.isNotEmpty) SizedBox(height: healthDp(context, 20)),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (order.deliveryFee > 0) ...[
                      Text(
                        '(배송비: ${PriceFormatter.format(order.deliveryFee)}원)',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 5)),
                    ],
                    Text(
                      '총 ${PriceFormatter.format(order.totalPrice)}원',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusActions != null) ...[
                SizedBox(height: healthDp(context, 20)),
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
    final thumb = healthDp(context, 80);
    return ClipRRect(
      borderRadius: BorderRadius.circular(healthDp(context, 4)),
      child: SizedBox(
        width: thumb,
        height: thumb,
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

  bool _isCardPayment(OrderDetailModel order) {
    final method = order.paymentMethod;
    return method.contains('신용') || method.contains('카드');
  }

  bool _isBankTransferPayment(OrderDetailModel order) {
    return order.paymentMethod.contains('계좌이체');
  }

  String _paymentInfoKvLabel(OrderDetailModel order) {
    if (_isBankTransferPayment(order)) return '주문번호 :';
    return '결제카드 :';
  }

  String _paymentInfoKvValue(OrderDetailModel order) {
    if (_isBankTransferPayment(order)) return order.odId;
    if (_isCardPayment(order)) return _formatCardPaymentLine(order);
    final detail = (order.paymentMethodDetail ?? '').trim();
    return detail.isEmpty ? '-' : detail;
  }

  String _formatReservationTimeRange(OrderDetailModel order) {
    final st = order.reservationTime?.trim();
    final et = order.reservationEndTime?.trim();
    if (st != null && st.isNotEmpty && et != null && et.isNotEmpty) {
      return '$st ~ $et';
    }
    if (st != null && st.isNotEmpty) return st;
    if (et != null && et.isNotEmpty) return et;
    return '-';
  }

  /// 진행 카드·주문일자/주문번호 — 375 기준 10sp, 줄높이 1 (간격은 SizedBox만)
  TextStyle _detailMetaTextStyle(BuildContext context) {
    return TextStyle(
      color: _kInk,
      fontSize: healthSp(context, 10),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }

  String _cardDisplayName(OrderDetailModel order) {
    var card = (order.paymentMethodDetail ?? '').trim();
    if (card.startsWith('(') && card.endsWith(')')) {
      card = card.substring(1, card.length - 1).trim();
    }
    return card.isEmpty ? '-' : card;
  }

  /// 결제카드 한 줄 — `현대카드 00403582` (카드명 + od_app_no)
  String _formatCardPaymentLine(OrderDetailModel order) {
    final card = _cardDisplayName(order);
    final approval = (order.odAppNo ?? '').trim();
    if (card == '-' && approval.isEmpty) return '-';
    if (approval.isEmpty) return card;
    if (card == '-') return approval;
    return '$card $approval';
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
        padding: EdgeInsets.all(healthDp(context, 20)),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.paymentMethod.isEmpty ? '결제수단' : order.paymentMethod,
              style: TextStyle(
                color: Color(0xFF898383),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                letterSpacing: healthDp(context, -0.6),
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            _detailVirtualBankRow(
              bankName: bankName.isEmpty ? '-' : bankName,
              accountNo: accountNo.isEmpty ? '-' : accountNo,
            ),
            SizedBox(height: healthDp(context, 10)),
            _detailKvLine('입금기한 :', deadlineLabel),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.paymentMethod.isEmpty ? '결제수단' : order.paymentMethod,
            style: TextStyle(
              color: Color(0xFF898383),
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: healthDp(context, -0.6),
            ),
          ),
          SizedBox(height: healthDp(context, 20)),
          _detailKvLine(_paymentInfoKvLabel(order), _paymentInfoKvValue(order)),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine(
            '결제일 :',
            DateDisplayFormatter.formatDotDateTimeFull(order.orderDate),
          ),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine('총 결제 금액 :', '${PriceFormatter.format(order.totalPrice)}원'),
        ],
      ),
    );
  }

  /// 결제·할인 카드 KV — 375 기준 12sp, 줄높이 1 (행 간격은 SizedBox 10만)
  TextStyle _detailKvLabelStyle(BuildContext context) {
    return TextStyle(
      color: _kMuted,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      letterSpacing: healthDp(context, -0.6),
      height: 1.1,
    );
  }

  TextStyle _detailKvValueStyle(BuildContext context) {
    return TextStyle(
      color: _kInk,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
      letterSpacing: healthDp(context, -0.6),
      height: 1,
    );
  }

  TextStyle _bankLineBaseTextStyle() {
    return TextStyle(
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      letterSpacing: healthDp(context, -0.6),
      height: 1,
    );
  }

  Widget _detailVirtualBankRow({
    required String bankName,
    required String accountNo,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '입금 은행 :',
          style: _bankLineBaseTextStyle().copyWith(
            color: _kMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: healthDp(context, 5)),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 6),
            children: [
              Text(
                '$bankName $accountNo',
                style: _bankLineBaseTextStyle().copyWith(
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
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 5),
                        vertical: healthDp(context, 3.5),
                      ),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: healthDp(context, 0.5),
                            color: const Color(0xFFD2D2D2),
                          ),
                          borderRadius: BorderRadius.circular(healthDp(context, 4)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '복사',
                            style: TextStyle(
                              color: Color(0xFF898686),
                              fontSize: healthSp(context, 8),
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
        Text(label, style: _detailKvLabelStyle(context)),
        SizedBox(width: healthDp(context, 5)),
        Expanded(child: Text(value, style: _detailKvValueStyle(context))),
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
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailKvLine(
            '쿠폰할인 :',
            coupon > 0 ? '${PriceFormatter.format(coupon)}원' : '0원',
          ),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine(
            '포인트할인 :',
            point > 0 ? '${PriceFormatter.format(point)}원' : '0원',
          ),
          SizedBox(height: healthDp(context, 10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 할인 금액 :', style: _detailKvLabelStyle(context)),
              SizedBox(width: healthDp(context, 5)),
              Text(
                '${PriceFormatter.format(totalDisc)}원',
                style: _detailKvValueStyle(context),
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
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailKvLine('담당 한의사 :', '정대진 원장'),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine(
            '예약 일자 :',
            DateDisplayFormatter.formatReservationDateWithWeekday(order.reservationDate),
          ),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine('예약 시간 :', _formatReservationTimeRange(order)),
        ],
      ),
    );
  }

  Widget _buildDetailDeliveryCard(OrderDetailModel order) {
    final addr = '${order.recipientAddress} ${order.recipientAddressDetail}'.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailKvLine('이름 :', order.recipientName),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine('연락처 :', order.recipientPhone),
          SizedBox(height: healthDp(context, 10)),
          _detailKvLine('주소 :', addr.isEmpty ? '-' : addr),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송 요청사항 :',
            style: TextStyle(
              color: _kMutedLabel,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: healthDp(context, -0.6),
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            order.deliveryMessage?.isNotEmpty == true ? order.deliveryMessage! : '-',
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              letterSpacing: healthDp(context, -0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusActionButtons(OrderDetailModel order) {
    final isPrescription = order.isPrescriptionOrder;
    final specs = <({String label, VoidCallback? onTap})>[];

    if (_isPaymentStageDetail(order) || _isPreparingStageDetail(order)) {
      specs.add((label: '배송지변경', onTap: _changeDeliveryAddress));
      if (isPrescription) {
        specs.add((label: '예약시간변경', onTap: _showReservationTimeChangeDialog));
      }
      specs.add((label: '주문취소', onTap: _cancelOrder));
    } else if (_isDeliveringStageDetail(order)) {
      specs.add((label: '배송조회', onTap: _trackDelivery));
      specs.add((label: '수령확인', onTap: _confirmPurchase));
    } else if (_isCompletedStageDetail(order)) {
      specs.add((label: '리뷰쓰기', onTap: _writeReviewFromDetail));
      specs.add((label: '교환/환불', onTap: _openRefundApply));
    } else if (_isExchangeStageDetail(order)) {
      specs.add((label: '교환취소', onTap: null));
    } else if (_isRefundStageDetail(order)) {
      specs.add((label: '환불취소', onTap: null));
    }

    if (specs.isEmpty) return null;
    return _detailOrderActionButtonRow(specs);
  }

  /// 왼쪽부터: 1번 핑크/흰 · 2번 흰/핑크 · 3번 회색/0xFF898686
  ({Color background, Color foreground, Color? border}) _detailOrderActionColors(
    int index,
  ) {
    if (index == 0) {
      return (background: _kPink, foreground: Colors.white, border: null);
    }
    if (index == 1) {
      return (background: Colors.white, foreground: _kPink, border: _kPink);
    }
    return (background: _kBorder, foreground: _kMuted, border: null);
  }

  /// 375 기준 액션 버튼 행 — 오른쪽 정렬, 버튼 간격 10 (공간 부족 시 너비만 축소)
  Widget _detailOrderActionButtonRow(
    List<({String label, VoidCallback? onTap})> specs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = specs.length;
        final gap = healthDp(context, 10);
        final designW = healthDp(context, 87);
        final btnH = healthDp(context, 34);
        final totalGaps = count > 1 ? (count - 1) * gap : 0.0;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final needed = count * designW + totalGaps;
        final btnW = needed <= maxW
            ? designW
            : ((maxW - totalGaps) / count).clamp(0.0, designW);

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _detailOrderActionButton(
                label: specs[i].label,
                index: i,
                onTap: specs[i].onTap,
                width: btnW,
                height: btnH,
              ),
            ],
          ],
        );
      },
    );
  }

  TextStyle _detailOrderActionTextStyle({
    required Color color,
    bool enabled = true,
  }) {
    return TextStyle(
      color: color.withValues(alpha: enabled ? 1 : 0.45),
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }

  SizedBox _detailOrderActionSizedBox({
    required Widget child,
    required double width,
    required double height,
  }) {
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _detailOrderActionButton({
    required String label,
    required int index,
    VoidCallback? onTap,
    required double width,
    required double height,
  }) {
    final enabled = onTap != null;
    final colors = _detailOrderActionColors(index);
    final bg = enabled
        ? colors.background
        : colors.background.withValues(
            alpha: colors.background == Colors.white ? 1 : 0.45,
          );
    final fg = enabled ? colors.foreground : colors.foreground.withValues(alpha: 0.45);
    final borderColor = colors.border == null
        ? null
        : (enabled ? colors.border! : colors.border!.withValues(alpha: 0.35));

    return _detailOrderActionSizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
          child: Container(
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              border: borderColor == null
                  ? null
                  : Border.all(
                      width: healthDp(context, 1),
                      color: borderColor,
                    ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 2)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: _detailOrderActionTextStyle(color: fg, enabled: true),
                ),
              ),
            ),
          ),
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

  bool _isExchangeStageDetail(OrderDetailModel order) {
    return order.displayStatus.contains('교환') ||
        order.odStatus.contains('교환');
  }

  bool _isRefundStageDetail(OrderDetailModel order) {
    return order.displayStatus.contains('환불') ||
        order.odStatus.contains('환불');
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

    if (result == true && mounted) {
      _loadOrderDetail();
    }
  }

  Future<void> _cancelOrder() async {
    if (_orderDetail == null) return;
    final user = await AuthService.getUser();
    if (user == null) return;

    final ok = await OrderFlowDialogs.runOrderCancelFlow(
      context,
      odId: _orderDetail!.odId,
      mbId: user.id,
      orderDetail: _orderDetail,
    );
    if (ok && mounted) _loadOrderDetail();
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

  Future<void> _openRefundApply() async {
    if (_orderDetail == null) return;
    final odId = widget.orderNumber.isNotEmpty ? widget.orderNumber : _orderDetail!.odId;
    final route = _orderDetail!.isPrescriptionOrder ? '/refund' : '/refund-general';
    await Navigator.pushNamed(
      context,
      route,
      arguments: {'orderNumber': odId},
    );
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
}

