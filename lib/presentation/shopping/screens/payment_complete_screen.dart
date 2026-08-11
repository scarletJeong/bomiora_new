import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart' as delivery;
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/dropdown_btn.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../user/delivery/widgets/delivery_address_change_popup_ver2.dart';
import '../../user/delivery/widgets/order_flow_dialogs.dart';
import '../../user/delivery/widgets/reservation_time_change_popup.dart';
import '../data/payment_complete_preview_data.dart';
import '../utils/cart_navigation.dart';
import '../widgets/payment_product_card.dart';
import '../widgets/prescription_booking_progress_bar.dart';

class PaymentCompleteScreen extends StatefulWidget {
  const PaymentCompleteScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<PaymentCompleteScreen> createState() => _PaymentCompleteScreenState();
}

class _PaymentCompleteScreenState extends State<PaymentCompleteScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _muted = Color(0xFF898686);
  static const Color _cardBorder = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';
  static const _deliveryMemoPresets = <String>[
    '문 앞에 놓아주세요',
    '경비실에 맡겨주세요',
    '직접 받겠습니다',
    '배송 전 연락바랍니다',
    '부재 시 연락주세요',
  ];

  bool _loading = true;
  String? _error;
  OrderDetailModel? _order;
  String _deliveryMemo = '';
  bool _paymentBreakdownExpanded = true;
  bool _handlingBlockedBack = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    if (PaymentCompletePreviewData.shouldUsePreview(widget.orderId)) {
      final preview = PaymentCompletePreviewData.previewOrder;
      setState(() {
        _order = preview;
        _deliveryMemo = (preview.deliveryMessage ?? '').trim();
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.trim().isEmpty) {
        setState(() {
          _error = '로그인 정보가 없습니다.';
          _loading = false;
        });
        return;
      }

      final result = await delivery.OrderService.getOrderDetail(
        odId: widget.orderId,
        mbId: user.id,
      );

      if (result['success'] != true || result['order'] is! OrderDetailModel) {
        setState(() {
          _error = (result['message'] ?? '주문 정보를 불러오지 못했습니다.').toString();
          _loading = false;
        });
        return;
      }

      final order = result['order'] as OrderDetailModel;
      setState(() {
        _order = order;
        _deliveryMemo = (order.deliveryMessage ?? '').trim();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '주문 정보를 불러오는 중 오류가 발생했습니다: $e';
        _loading = false;
      });
    }
  }

  Future<void> _onDeliveryMemoChanged(String value) async {
    final next = value.trim();
    final prev = _deliveryMemo;
    if (next == prev || _order == null) return;
    if (PaymentCompletePreviewData.shouldUsePreview(widget.orderId)) {
      setState(() => _deliveryMemo = next);
      return;
    }

    setState(() => _deliveryMemo = next);

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) {
      if (mounted) setState(() => _deliveryMemo = prev);
      return;
    }

    final result = await delivery.OrderService.updateDeliveryMemo(
      odId: _order!.odId,
      mbId: user.id,
      memo: next,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      AppToastOverlay.show(context, '배송요청사항이 변경되었습니다.');
    } else {
      setState(() => _deliveryMemo = prev);
      AppToastOverlay.show(
        context,
        result['message']?.toString() ?? '배송요청사항 변경에 실패했습니다.',
      );
    }
  }

  String _fmtPrice(int value) => '${PriceFormatter.format(value)} 원';

  String _fmtPriceWon(int value) => '${PriceFormatter.format(value)}원';

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return raw;
  }

  String _fullAddress(OrderDetailModel order) {
    final parts = <String>[
      order.recipientAddress.trim(),
      order.recipientAddressDetail.trim(),
    ].where((e) => e.isNotEmpty);
    return parts.join('\n');
  }

  bool _isVirtualAccountOrder(OrderDetailModel order) {
    return order.paymentMethod.contains('가상');
  }

  bool _isCashPayment(OrderDetailModel order) {
    return order.paymentMethod.contains('가상') ||
        order.paymentMethod.contains('계좌이체');
  }

  bool _isAwaitingDeposit(OrderDetailModel order) {
    if (!_isVirtualAccountOrder(order)) return false;
    final status = '${order.displayStatus} ${order.odStatus}'.toLowerCase();
    return status.contains('입금대기') ||
        status.contains('결제대기') ||
        status.contains('pending') ||
        order.odStatus == '주문' ||
        order.displayStatus.contains('입금대기');
  }

  String _formatDepositDeadline(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return raw.trim();
    final y = digits.substring(0, 4);
    final mo = digits.substring(4, 6);
    final d = digits.substring(6, 8);
    if (digits.length >= 12) {
      final h = digits.substring(8, 10);
      final mi = digits.substring(10, 12);
      return '$y.$mo.$d $h:$mi까지 입금';
    }
    return '$y.$mo.$d까지 입금';
  }

  static const String _kVirtualAccountHolder = '(주)보미오라';

  ({
    String bankName,
    String accountNo,
    String bankLine,
    String? holder,
    String deadline,
    String copyText,
  }) _parseVirtualBankAccount(OrderDetailModel order) {
    final raw = (order.odBankAccount ?? order.paymentMethodDetail ?? '').trim();
    final parts = raw
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final bankName = parts.isNotEmpty ? parts[0] : '';
    final accountNo = parts.length >= 2 ? parts[1] : '';
    final deadlineRaw = parts.length >= 3 ? parts[2] : '';
    // 가상계좌 예금주는 항상 (주)보미오라 (비대면/일반 공통)
    final bankLine = [
      if (bankName.isNotEmpty) bankName,
      if (accountNo.isNotEmpty) accountNo,
    ].join(' ');

    return (
      bankName: bankName.isEmpty ? '-' : bankName,
      accountNo: accountNo,
      bankLine: bankLine.isEmpty ? raw : bankLine,
      holder: _kVirtualAccountHolder,
      deadline: _formatDepositDeadline(deadlineRaw),
      copyText: accountNo.isNotEmpty
          ? accountNo
          : (bankLine.isEmpty ? raw : bankLine),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('계좌번호가 복사되었습니다.')),
    );
  }

  int _pointDiscountAmount(OrderDetailModel order) {
    if (order.pointDiscount > 0) return order.pointDiscount;
    return order.discountAmount;
  }

  int _couponDiscountAmount(OrderDetailModel order) {
    if (order.couponDiscount > 0) return order.couponDiscount;
    final leftover = order.discountAmount - order.pointDiscount;
    return leftover > 0 ? leftover : 0;
  }

  int _expectedPoint(OrderDetailModel order) {
    return (order.totalPrice * 0.01).floor();
  }

  bool _looksLikeReservationSegment(String part) {
    if (part.contains('~')) return true;
    return RegExp(r'\d{4}\.\d{2}\.\d{2}').hasMatch(part) && part.contains(':');
  }

  ({List<String> optionParts, String? reservationText}) _splitOptionAndReservation(
    String optionText,
  ) {
    if (optionText.isEmpty) {
      return (optionParts: <String>[], reservationText: null);
    }

    final segments = optionText
        .split(RegExp(r'\s*/\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final optionParts = <String>[];
    final reservationParts = <String>[];

    for (final segment in segments) {
      if (_looksLikeReservationSegment(segment)) {
        reservationParts.add(segment);
      } else {
        optionParts.add(segment);
      }
    }

    return (
      optionParts: optionParts,
      reservationText:
          reservationParts.isEmpty ? null : reservationParts.join(' / '),
    );
  }

  String _formatReservationDateCompact(String? raw) {
    final d = DateDisplayFormatter.tryParseYmdFlexible(raw);
    if (d == null) return '-';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm월$dd일(${weekdays[d.weekday - 1]})';
  }

  String _formatReservationTimeRange(OrderDetailModel order) {
    final st = order.reservationTime?.trim();
    final et = order.reservationEndTime?.trim();
    if (st != null && st.isNotEmpty && et != null && et.isNotEmpty) {
      return '$st - $et';
    }
    if (st != null && st.isNotEmpty) return st;
    if (et != null && et.isNotEmpty) return et;

    for (final item in order.products) {
      final parsed = _splitOptionAndReservation((item.ctOption ?? '').trim());
      if (parsed.reservationText != null) {
        final text = parsed.reservationText!;
        final match = RegExp(
          r'(\d{1,2}:\d{2})\s*[~\-–]\s*(\d{1,2}:\d{2})',
        ).firstMatch(text);
        if (match != null) {
          return '${match.group(1)} - ${match.group(2)}';
        }
        return text;
      }
    }
    return '-';
  }

  bool _hasReservationInfo(OrderDetailModel order) {
    if (!order.isPrescriptionOrder) return false;
    if ((order.reservationDate ?? '').trim().isNotEmpty) return true;
    return order.products.any((item) {
      final parsed = _splitOptionAndReservation((item.ctOption ?? '').trim());
      return parsed.reservationText != null;
    });
  }

  String _reservationDateLabel(OrderDetailModel order) {
    if ((order.reservationDate ?? '').trim().isNotEmpty) {
      return _formatReservationDateCompact(order.reservationDate);
    }
    for (final item in order.products) {
      final parsed = _splitOptionAndReservation((item.ctOption ?? '').trim());
      final text = parsed.reservationText;
      if (text == null) continue;
      final match = RegExp(
        r'(\d{4})\.(\d{2})\.(\d{2})\((.)\)',
      ).firstMatch(text);
      if (match != null) {
        return '${match.group(2)}월${match.group(3)}일(${match.group(4)})';
      }
    }
    return '-';
  }

  String _paymentDateLabel(OrderDetailModel order) {
    final raw = order.orderDate.trim();
    if (raw.isEmpty) return '-';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 8) {
      return '${digits.substring(0, 4)}.${digits.substring(4, 6)}.${digits.substring(6, 8)}';
    }
    return raw.split(' ').first;
  }

  void _openOrderDetail(OrderDetailModel order) {
    Navigator.pushNamed(
      context,
      '/order-detail',
      arguments: {'orderNumber': order.odId, 'odId': order.odId},
    );
  }

  /// 비대면 주문 여부 (플래그 + 라인상품 kind)
  bool _isPrescriptionPurchase(OrderDetailModel order) {
    if (order.isPrescriptionOrder) return true;
    return order.products.any(
      (p) => orderItemProductKind(p) == 'prescription',
    );
  }

  void _continueShopping(OrderDetailModel order) {
    // 비대면 → /product/, 일반 → /product-general/
    final route = _isPrescriptionPurchase(order)
        ? '/product/'
        : '/product-general/';
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (r) => r.isFirst,
    );
  }

  Future<void> _handleBlockedBack() async {
    if (_handlingBlockedBack || !mounted) return;
    _handlingBlockedBack = true;

    // 비대면 배송완료 이력 있으면 통합 장바구니, 없으면 이번 주문 유형별 장바구니
    final isRx = _order?.isPrescriptionOrder == true;
    await CartNavigation.openCart(
      context,
      prescriptionTab: isRx,
      clearStack: true,
    );

    if (mounted) {
      _handlingBlockedBack = false;
    }
  }

  Future<void> _openDeliveryAddressChange() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeliveryAddressChangePopup(orderId: widget.orderId),
    );
    if (result == true && mounted) {
      await _loadOrder();
    }
  }

  Future<void> _cancelOrder(OrderDetailModel order) async {
    final user = await AuthService.getUser();
    if (user == null || !mounted) return;
    final ok = await OrderFlowDialogs.runOrderCancelFlow(
      context,
      odId: order.odId,
      mbId: user.id,
      orderDetail: order,
    );
    if (ok && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/order',
        (route) => route.isFirst,
      );
    }
  }

  Future<void> _changeReservationTime(OrderDetailModel order) async {
    final date = order.reservationDate?.trim();
    final time = order.reservationTime?.trim();
    if (date == null || date.isEmpty || time == null || time.isEmpty) {
      return;
    }

    final changeResult = await showGeneralDialog<bool>(
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
              orderId: order.odId,
              currentDate: date,
              currentTime: time,
            ),
          ],
        );
      },
    );

    if (changeResult == true && mounted) {
      await _loadOrder();
    }
  }

  BoxDecoration _sectionCardDecoration(
    BuildContext context, {
    double radius = 15,
  }) {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _cardBorder, width: 1),
      borderRadius: BorderRadius.circular(healthDp(context, radius)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRx = _order?.isPrescriptionOrder == true;
    final awaiting = _order != null && _isAwaitingDeposit(_order!);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBlockedBack());
        }
      },
      child: MobileAppLayoutWrapper(
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: HealthAppBar(
            title: isRx
                ? (awaiting
                    ? '진료예약 중 _ 04 예약 대기중'
                    : '진료예약 중 _ 04 예약완료')
                : '주문 완료',
            centerTitle: false,
            onBack: _handleBlockedBack,
            bottom: isRx
                ? PrescriptionBookingProgressBar.asAppBarBottom(
                    currentStep: PrescriptionBookingSteps.complete,
                    stepProgress: awaiting ? 0.5 : 1,
                  )
                : null,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: _pink))
              : _error != null
                  ? _buildError()
                  : _buildContent(context, _order!),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(healthDp(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: healthSp(context, 14),
                fontFamily: _font,
              ),
            ),
            SizedBox(height: healthDp(context, 12)),
            OutlinedButton(
              onPressed: _loadOrder,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrderDetailModel order) {
    final awaiting = _isAwaitingDeposit(order);
    final hPad = healthDp(context, 27);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: healthDp(context, 20)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: healthDp(context, 672)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: healthDp(context, 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (awaiting) ...[
                  _buildPendingDepositCard(context, order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildOrderProductsCard(context, order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDeliveryCard(context, order),
                ] else ...[
                  _buildOrderProductsCard(context, order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDeliveryCard(context, order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildPaidPaymentCard(context, order),
                ],
                SizedBox(height: healthDp(context, 20)),
                _buildBottomActions(context, order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingDepositCard(
    BuildContext context,
    OrderDetailModel order,
  ) {
    final bank = _parseVirtualBankAccount(order);
    final holder = (bank.holder ?? '').trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: ShapeDecoration(
        color: const Color(0x0CFF5A8D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '입금을 기다리고 있어요',
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          Text(
            '기한 내 입금 시 주문이 완료됩니다',
            style: TextStyle(
              color: _pink,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 14)),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 15)),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        bank.bankName,
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _copyToClipboard(bank.copyText),
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 50)),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 12),
                          vertical: healthDp(context, 4),
                        ),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1,
                              color: Color(0xFFFF5C8D),
                            ),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 50)),
                          ),
                        ),
                        child: Text(
                          '복사',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFFF5C8D),
                            fontSize: healthSp(context, 12),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  bank.accountNo.isEmpty ? bank.bankLine : bank.accountNo,
                  style: TextStyle(
                    color: const Color(0xFF1F2937),
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        holder.isEmpty ? '예금주 : -' : '예금주 : $holder',
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.08,
                        ),
                      ),
                    ),
                    Text(
                      _fmtPriceWon(order.totalPrice),
                      style: TextStyle(
                        color: _pink,
                        fontSize: healthSp(context, 16),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: healthDp(context, 14),
                color: _pink,
              ),
              SizedBox(width: healthDp(context, 5)),
              Text(
                bank.deadline,
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, OrderDetailModel order) {
    final name = order.recipientName.isNotEmpty
        ? order.recipientName
        : order.ordererName;
    final memo = _deliveryMemo.trim();
    final memoItems = [
      ..._deliveryMemoPresets,
      if (memo.isNotEmpty && !_deliveryMemoPresets.contains(memo)) memo,
    ];
    final awaiting = _isAwaitingDeposit(order);
    // 일반상품 결제대기중에도 배송지 변경 노출 (핑크 아웃라인)
    final showAddressChange =
        !awaiting || !order.isPrescriptionOrder;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: _sectionCardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? '배송지' : name,
                  style: TextStyle(
                    color: const Color(0xFF333333),
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    height: 1.75,
                  ),
                ),
              ),
              if (showAddressChange)
                InkWell(
                  onTap: _openDeliveryAddressChange,
                  borderRadius: BorderRadius.circular(healthDp(context, 9999)),
                  child: Container(
                    height: healthDp(context, 30),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 12),
                      vertical: healthDp(context, 4),
                    ),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          width: 1,
                          color: _pink,
                        ),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 9999)),
                      ),
                    ),
                    child: Text(
                      '배송지 변경',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _pink,
                        fontSize: healthSp(context, 12),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            _formatPhone(
              order.recipientPhone.isNotEmpty
                  ? order.recipientPhone
                  : order.ordererPhone,
            ),
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          Text(
            _fullAddress(order),
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송 요청 사항',
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          DropdownBtn(
            buttonHeight: healthDp(context, 45),
            items: memoItems,
            value: memo,
            emptyText: '배송메모를 선택해주세요',
            emptyTextColor: _muted,
            valueTextColor: _ink,
            borderColor: const Color(0xFFD2D2D2),
            itemFontSizeBase: 12,
            itemTextAlign: TextAlign.left,
            onChanged: _onDeliveryMemoChanged,
          ),
          SizedBox(height: healthDp(context, 5)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 10),
                fontFamily: _font,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidPaymentCard(BuildContext context, OrderDetailModel order) {
    final bank = _parseVirtualBankAccount(order);
    final showDeposit = _isCashPayment(order) && bank.bankLine.trim().isNotEmpty;
    final holder = (bank.holder ?? '').trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: _sectionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _paymentBreakdownExpanded = !_paymentBreakdownExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          '총 결제비용',
                          style: TextStyle(
                            color: _ink,
                            fontSize: healthSp(context, 16),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.44,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 4)),
                        AnimatedRotation(
                          turns: _paymentBreakdownExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: healthDp(context, 16),
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _fmtPriceWon(order.totalPrice),
                      style: TextStyle(
                        color: _pink,
                        fontSize: healthSp(context, 20),
                        fontFamily: _font,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 2)),
                if (_expectedPoint(order) > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '예상 적립 포인트 ${PriceFormatter.format(_expectedPoint(order))} 점',
                      style: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 8),
                        fontFamily: _font,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.32,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          _paidInfoRow(
            context,
            label: '결제방식',
            value: order.paymentMethod.isEmpty ? '-' : order.paymentMethod,
          ),
          SizedBox(height: healthDp(context, 10)),
          _paidInfoRow(
            context,
            label: '결제일시',
            value: _paymentDateLabel(order),
            valueStyle: TextStyle(
              color: const Color(0xFF374151),
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              height: 1.43,
            ),
          ),
          if (showDeposit) ...[
            SizedBox(height: healthDp(context, 10)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
                  child: Text(
                    '입금정보',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.08,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      bank.bankLine,
                      style: TextStyle(
                        color: _ink,
                        fontSize: healthSp(context, 10),
                        fontFamily: _font,
                        fontWeight: FontWeight.w300,
                        height: 1.2,
                      ),
                    ),
                    if (holder.isNotEmpty)
                      Text(
                        '(예금주 : $holder)',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 10),
                          fontFamily: _font,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
          if (_paymentBreakdownExpanded) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            SizedBox(height: healthDp(context, 10)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
              child: _buildPaymentBreakdownDetails(context, order),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paidInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.08,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ??
                  TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownDetails(
    BuildContext context,
    OrderDetailModel order,
  ) {
    final coupon = _couponDiscountAmount(order);
    final point = _pointDiscountAmount(order);
    final rows = <Widget>[];

    void addRow({
      required String label,
      required String value,
      required Color labelColor,
      required Color valueColor,
    }) {
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: healthDp(context, 10)));
      }
      rows.add(
        _paymentBreakdownRow(
          context,
          label: label,
          value: value,
          labelColor: labelColor,
          valueColor: valueColor,
        ),
      );
    }

    if (order.productPrice > 0) {
      addRow(
        label: '구매금액',
        value: _fmtPrice(order.productPrice),
        labelColor: _muted,
        valueColor: _ink,
      );
    }
    if (coupon > 0) {
      addRow(
        label: '쿠폰할인',
        value: '-${PriceFormatter.format(coupon)} 원',
        labelColor: _pink,
        valueColor: _pink,
      );
    }
    if (point > 0) {
      addRow(
        label: '포인트할인',
        value: '-${PriceFormatter.format(point)} 원',
        labelColor: _pink,
        valueColor: _pink,
      );
    }
    if (order.deliveryFee > 0) {
      addRow(
        label: '배송비',
        value: _fmtPrice(order.deliveryFee),
        labelColor: _muted,
        valueColor: _ink,
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: rows);
  }

  Widget _paymentBreakdownRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
    double valueSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: healthSp(context, valueSize),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderProductsCard(
    BuildContext context,
    OrderDetailModel order,
  ) {
    final showReservation = _hasReservationInfo(order);
    final awaiting = _isAwaitingDeposit(order);

    // 일반상품: 하나의 카드 안에 업체별 섹션
    if (!order.isPrescriptionOrder) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentGeneralProductCard(
            cartItems: cartItemsFromOrderItems(
              order.products,
              odId: order.odId,
            ),
            title: '결제 예정 목록',
            showFooterNote: true,
          ),
          SizedBox(height: healthDp(context, 10)),
          _buildOrderCancelButton(context, order),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: _sectionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showReservation) ...[
            _buildReservationBlock(context, order),
            SizedBox(height: healthDp(context, awaiting ? 10 : 20)),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            SizedBox(height: healthDp(context, 20)),
          ],
          Text(
            '결제 예정 목록 (${order.products.length})',
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 16),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.44,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          PaymentProductCard(
            cartItems: cartItemsFromOrderItems(
              order.products,
              odId: order.odId,
            ),
            showHeader: false,
            showReservationBanner: false,
            showSameReservationHint: false,
          ),
          SizedBox(height: healthDp(context, 20)),
          _buildOrderCancelButton(context, order),
        ],
      ),
    );
  }

  Widget _buildOrderCancelButton(
    BuildContext context,
    OrderDetailModel order,
  ) {
    return InkWell(
      onTap: () => _cancelOrder(order),
      borderRadius: BorderRadius.circular(healthDp(context, 9999)),
      child: Container(
        width: double.infinity,
        height: healthDp(context, 34),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
          ),
        ),
        child: Text(
          '주문취소',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReservationBlock(
    BuildContext context,
    OrderDetailModel order,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '보미오라 한의원',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 2)),
        Text(
          '진료 예약 일정',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 16),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.44,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          height: 1,
          color: const Color(0xFFE8E8E8),
        ),
        SizedBox(height: healthDp(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _reservationMeta(
              context,
              icon: Icons.calendar_today_outlined,
              label: _reservationDateLabel(order),
            ),
            _reservationMeta(
              context,
              icon: Icons.access_time,
              label: _formatReservationTimeRange(order),
            ),
            _reservationMeta(
              context,
              icon: Icons.person_outline,
              label: '정대진 한의사',
            ),
          ],
        ),
        if (!_isAwaitingDeposit(order)) ...[
          SizedBox(height: healthDp(context, 10)),
          InkWell(
            onTap: () => _changeReservationTime(order),
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
            child: Container(
              width: double.infinity,
              height: healthDp(context, 30),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 1, color: _pink),
                  borderRadius: BorderRadius.circular(healthDp(context, 9999)),
                ),
              ),
              child: Text(
                '예약 시간 변경',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reservationMeta(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: healthDp(context, 24), color: _pink),
          SizedBox(height: healthDp(context, 4)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF333333),
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, OrderDetailModel order) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _openOrderDetail(order),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: Container(
              height: healthDp(context, 40),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, 0.5),
                    color: const Color(0xFFD2D2D2),
                  ),
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '주문 상세',
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 20)),
        Expanded(
          child: InkWell(
            onTap: () => _continueShopping(order),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
            child: Container(
              height: healthDp(context, 40),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: _pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '계속 쇼핑하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
