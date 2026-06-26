import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart' as delivery;
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../user/delivery/widgets/delivery_address_change_popup_ver2.dart';
import '../data/payment_complete_preview_data.dart';

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
  static const Color _cardBorder = Color(0xFFE1E3E4);
  static const Color _innerBorder = Color(0xFFEDEEEF);
  static const Color _productBorder = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  bool _loading = true;
  String? _error;
  OrderDetailModel? _order;
  bool _paymentBreakdownExpanded = false;
  bool _handlingBlockedBack = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    if (PaymentCompletePreviewData.shouldUsePreview(widget.orderId)) {
      setState(() {
        _order = PaymentCompletePreviewData.previewOrder;
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

      setState(() {
        _order = result['order'] as OrderDetailModel;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '주문 정보를 불러오는 중 오류가 발생했습니다: $e';
        _loading = false;
      });
    }
  }

  String _fmtPrice(int value) => '${PriceFormatter.format(value)} 원';

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

  String _paymentMethodLabel(OrderDetailModel order) {
    final detail = (order.paymentMethodDetail ?? '').trim();
    if (detail.isEmpty) return order.paymentMethod;
    return '${order.paymentMethod} $detail';
  }

  bool _isVirtualAccountOrder(OrderDetailModel order) {
    return order.paymentMethod.contains('가상');
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
      return '$y.$mo.$d $h:$mi까지';
    }
    return '$y.$mo.$d까지';
  }

  ({
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
    final holder = parts.length >= 4 ? parts[3] : null;
    final bankLine = [
      if (bankName.isNotEmpty) bankName,
      if (accountNo.isNotEmpty) accountNo,
    ].join(' ');

    return (
      bankLine: bankLine.isEmpty ? raw : bankLine,
      holder: holder,
      deadline: _formatDepositDeadline(deadlineRaw),
      copyText: bankLine.isEmpty ? raw : bankLine,
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

  void _openOrderDetail(OrderDetailModel order) {
    Navigator.pushNamed(
      context,
      '/order-detail',
      arguments: {'orderNumber': order.odId, 'odId': order.odId},
    );
  }

  void _continueShopping(OrderDetailModel order) {
    final route =
        order.isPrescriptionOrder ? '/bomiora-introduce' : '/healthcare-store';
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (route) => route.isFirst,
    );
  }

  Future<void> _handleBlockedBack() async {
    if (_handlingBlockedBack || !mounted) return;
    _handlingBlockedBack = true;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (dialogContext) {
          return Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: healthDp(context, 40)),
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 24),
                vertical: healthDp(context, 20),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(healthDp(context, 12)),
              ),
              child: Text(
                '잘못된 페이지 이동입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.of(context).pop();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/cart',
      (route) => route.isFirst,
    );
    _handlingBlockedBack = false;
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

  BoxDecoration _sectionCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _cardBorder, width: healthDp(context, 1)),
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: healthDp(context, 12),
          offset: Offset(0, healthDp(context, 2)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
            title: '주문 완료',
            centerTitle: false,
            onBack: _handleBlockedBack,
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
                _buildOrderHeader(context, order),
                SizedBox(height: healthDp(context, 20)),
                _buildDeliveryCard(context, order),
                SizedBox(height: healthDp(context, 20)),
                _isVirtualAccountOrder(order)
                    ? _buildVirtualAccountPaymentCard(context, order)
                    : _buildPaidPaymentCard(context, order),
                SizedBox(height: healthDp(context, 20)),
                _buildOrderProductsCard(context, order),
                SizedBox(height: healthDp(context, 20)),
                _buildBottomActions(context, order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(BuildContext context, OrderDetailModel order) {
    if (_isVirtualAccountOrder(order)) {
      return _buildVirtualAccountHeader(context);
    }
    return _buildSuccessHeader(context);
  }

  Widget _buildSuccessHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: healthDp(context, 40),
          height: healthDp(context, 40),
          decoration: BoxDecoration(
            color: _pink,
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x19000000),
                blurRadius: healthDp(context, 4),
                offset: Offset(0, healthDp(context, 2)),
                spreadRadius: healthDp(context, -2),
              ),
              BoxShadow(
                color: const Color(0x19000000),
                blurRadius: healthDp(context, 6),
                offset: Offset(0, healthDp(context, 4)),
                spreadRadius: healthDp(context, -1),
              ),
            ],
          ),
          child: Icon(
            Icons.check,
            color: Colors.white,
            size: healthDp(context, 28),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: healthDp(context, 10)),
          child: Text(
            '주문이 완료되었습니다!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 18),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualAccountHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 0)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: healthDp(context, 50),
            height: healthDp(context, 50),
            decoration: BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.circular(healthDp(context, 9999)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x19000000),
                  blurRadius: healthDp(context, 4),
                  offset: Offset(0, healthDp(context, 2)),
                  spreadRadius: healthDp(context, -2),
                ),
                BoxShadow(
                  color: const Color(0x19000000),
                  blurRadius: healthDp(context, 6),
                  offset: Offset(0, healthDp(context, 4)),
                  spreadRadius: healthDp(context, -1),
                ),
              ],
            ),
            child: Icon(
              Icons.schedule,
              color: Colors.white,
              size: healthDp(context, 28),
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          Padding(
            padding: EdgeInsets.only(top: healthDp(context, 8)),
            child: Text(
              '입금을 기다리고 있어요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: healthSp(context, 18),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            '입금 기한 내에 입금이 완료되어야 주문이 정상적으로 접수됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              letterSpacing: healthDp(context, -0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, OrderDetailModel order) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: _sectionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '배송지 정보',
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: _openDeliveryAddressChange,
                borderRadius: BorderRadius.circular(healthDp(context, 20)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 4),
                    vertical: healthDp(context, 4),
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _pink, width: healthDp(context, 0.5)),
                    borderRadius: BorderRadius.circular(healthDp(context, 20)),
                  ),
                  child: Text(
                    '배송지 변경',
                    style: TextStyle(
                      color: _pink,
                      fontSize: healthSp(context, 10),
                      fontFamily: _font,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
          Text(
            order.recipientName.isNotEmpty
                ? order.recipientName
                : order.ordererName,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            _formatPhone(
              order.recipientPhone.isNotEmpty
                  ? order.recipientPhone
                  : order.ordererPhone,
            ),
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            _fullAddress(order),
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
          if ((order.deliveryMessage ?? '').trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: healthDp(context, 12)),
              padding: EdgeInsets.only(top: healthDp(context, 12)),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _innerBorder,
                    width: healthDp(context, 1),
                  ),
                ),
              ),
              child: Text(
                order.deliveryMessage!.trim(),
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaidPaymentCard(BuildContext context, OrderDetailModel order) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: _sectionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 정보',
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 16),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          _buildPaymentMethodRow(context, order),
          SizedBox(height: healthDp(context, 16)),
          _buildTotalPaymentBreakdown(context, order),
        ],
      ),
    );
  }

  // 기싱계좌 - 결제 정보
  Widget _buildVirtualAccountPaymentCard(
    BuildContext context,
    OrderDetailModel order,
  ) {
    final bank = _parseVirtualBankAccount(order);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 20)),
      decoration: _sectionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 정보',
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 16),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          _buildPaymentMethodRow(context, order),
          SizedBox(height: healthDp(context, 16)),
          Padding(
            padding: EdgeInsets.only(
              right: healthDp(context, 16),
              bottom: healthDp(context, 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '입금 계좌 정보',
                      style: TextStyle(
                        color: _ink,
                        fontSize: healthSp(context, 14),
                        fontFamily: _font,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (bank.copyText.trim().isNotEmpty)
                      InkWell(
                        onTap: () => _copyToClipboard(bank.copyText),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 4)),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 6),
                            vertical: healthDp(context, 2),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _pink,
                              width: healthDp(context, 0.5),
                            ),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 4)),
                          ),
                          child: Text(
                            '복사',
                            style: TextStyle(
                              color: _pink,
                              fontSize: healthSp(context, 12),
                              fontFamily: _font,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  bank.bankLine,
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if ((bank.holder ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: healthDp(context, 4)),
                  Text(
                    '(예금주: ${bank.holder})',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 14),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: healthDp(context, 12)),
                  padding: EdgeInsets.only(top: healthDp(context, 12)),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _innerBorder,
                        width: healthDp(context, 1),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _paymentBreakdownExpanded =
                                !_paymentBreakdownExpanded;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '입금 금액',
                              style: TextStyle(
                                color: _ink,
                                fontSize: healthSp(context, 14),
                                fontFamily: _font,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${PriceFormatter.format(order.totalPrice)}원',
                                  style: TextStyle(
                                    color: _pink,
                                    fontSize: healthSp(context, 16),
                                    fontFamily: _font,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(width: healthDp(context, 5)),
                                AnimatedRotation(
                                  turns:
                                      _paymentBreakdownExpanded ? 0.5 : 0,
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: _ink,
                                    size: healthDp(context, 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_paymentBreakdownExpanded) ...[
                        SizedBox(height: healthDp(context, 12)),
                        _buildPaymentBreakdownDetails(context, order),
                      ],
                      SizedBox(height: healthDp(context, 16)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '입금 기한',
                            style: TextStyle(
                              color: _ink,
                              fontSize: healthSp(context, 14),
                              fontFamily: _font,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            bank.deadline,
                            style: TextStyle(
                              color: _pink,
                              fontSize: healthSp(context, 14),
                              fontFamily: _font,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(BuildContext context, OrderDetailModel order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '결제 수단',
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
        Flexible(
          child: Text(
            _paymentMethodLabel(order),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalPaymentBreakdown(
    BuildContext context,
    OrderDetailModel order,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _paymentBreakdownExpanded = !_paymentBreakdownExpanded;
            });
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 결제 금액',
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: healthSp(context, -0.2),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmtPrice(order.totalPrice),
                      style: TextStyle(
                        color: _pink,
                        fontSize: healthSp(context, 16),
                        fontFamily: _font,
                        fontWeight: FontWeight.w700,
                        letterSpacing: healthSp(context, -0.2),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 5)),
                    AnimatedRotation(
                      turns: _paymentBreakdownExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: _ink,
                        size: healthDp(context, 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_paymentBreakdownExpanded) ...[
          Divider(height: healthDp(context, 1), color: _innerBorder),
          Padding(
            padding: EdgeInsets.all(healthDp(context, 10)),
            child: _buildPaymentBreakdownDetails(context, order),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentBreakdownDetails(
    BuildContext context,
    OrderDetailModel order,
  ) {
    final pointDiscount = _pointDiscountAmount(order);

    return Column(
      children: [
        _paymentBreakdownRow(
          context,
          label: '주문 금액',
          value: _fmtPrice(order.productPrice),
          valueColor: _ink,
        ),
        SizedBox(height: healthDp(context, 12)),
        _paymentBreakdownRow(
          context,
          label: '포인트 할인',
          value: pointDiscount > 0
              ? '- ${_fmtPrice(pointDiscount)}'
              : _fmtPrice(0),
          valueColor: pointDiscount > 0 ? _pink : _ink,
        ),
        SizedBox(height: healthDp(context, 12)),
        _paymentBreakdownRow(
          context,
          label: '배송비',
          value: _fmtPrice(order.deliveryFee),
          valueColor: _ink,
        ),
      ],
    );
  }

  Widget _paymentBreakdownRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderProductsCard(BuildContext context, OrderDetailModel order) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _sectionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 20)),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _innerBorder,
                  width: healthDp(context, 1),
                ),
              ),
            ),
            child: Text(
              '주문 상품 (${order.products.length})',
              style: TextStyle(
                color: _ink,
                fontSize: healthSp(context, 16),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(healthDp(context, 10)),
            child: Column(
              children: [
                for (var i = 0; i < order.products.length; i++) ...[
                  if (i > 0) SizedBox(height: healthDp(context, 10)),
                  _productCard(context, order.products[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 주문 카드드
  Widget _productCard(BuildContext context, OrderItem item) {
    final imageUrl =
        ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    final thumb = healthDp(context, 72);
    final parsed = _splitOptionAndReservation((item.ctOption ?? '').trim());
    final optionParts = parsed.optionParts;
    final reservationText = parsed.reservationText;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _productBorder, width: healthDp(context, 1)),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 10),
              healthDp(context, 20),
              healthDp(context, 10),
              reservationText != null ? healthDp(context, 5) : healthDp(context, 20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl == null
                      ? Icon(
                          Icons.image,
                          color: _muted,
                          size: healthDp(context, 28),
                        )
                      : Image.network(
                          imageUrl,
                          width: thumb,
                          height: thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image,
                            color: _muted,
                            size: healthDp(context, 28),
                          ),
                        ),
                ),
                SizedBox(width: healthDp(context, 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itName,
                        style: TextStyle(
                          color: _ink,
                          fontSize: healthSp(context, 14),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 5)),
                      Wrap(
                        spacing: healthDp(context, 5),
                        runSpacing: healthDp(context, 4),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '수량: ${item.ctQty}',
                            style: TextStyle(
                              color: _muted,
                              fontSize: healthSp(context, 10),
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          for (final part in optionParts) ...[
                            _metaDivider(context),
                            Text(
                              part,
                              style: TextStyle(
                                color: _muted,
                                fontSize: healthSp(context, 10),
                                fontFamily: _font,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: healthDp(context, 5)),
                      Text(
                        '${PriceFormatter.format(item.totalPrice)}원',
                        style: TextStyle(
                          color: _ink,
                          fontSize: healthSp(context, 11),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (reservationText != null) ...[
            Container(
              width: double.infinity,
              height: healthDp(context, 0.5),
              color: const Color(0xFFD2D2D2),
            ),
            Padding(
              padding: EdgeInsets.all(healthDp(context, 10)),
              child: Text(
                reservationText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 13),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaDivider(BuildContext context) {
    return Container(
      width: healthDp(context, 0.5),
      height: healthDp(context, 10),
      color: _muted,
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
