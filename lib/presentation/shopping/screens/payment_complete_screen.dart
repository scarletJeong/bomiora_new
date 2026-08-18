import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart' as delivery;
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../user/delivery/widgets/delivery_address_change_popup_ver2.dart';
import '../../user/delivery/widgets/detail/delivery_detail_address_section.dart';
import '../../user/delivery/widgets/detail/delivery_detail_deposit_card.dart';
import '../../user/delivery/widgets/detail/delivery_detail_general_products_section.dart';
import '../../user/delivery/widgets/detail/delivery_detail_payment_section.dart';
import '../../user/delivery/widgets/detail/delivery_detail_products_section.dart';
import '../../user/delivery/widgets/detail/delivery_detail_reservation_products_card.dart';
import '../../user/delivery/widgets/order_flow_dialogs.dart';
import '../../user/delivery/widgets/reservation_time_change_popup.dart';
import '../data/payment_complete_preview_data.dart';
import '../utils/cart_navigation.dart';
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

  bool _isVirtualAccountOrder(OrderDetailModel order) {
    return order.paymentMethod.contains('가상');
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
                    ? '진료예약완료 _ 04 예약 대기중'
                    : '진료예약완료 _ 04 예약완료')
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
                  DeliveryDetailDepositCard(order: order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildOrderProductsCard(context, order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDeliveryAddressSection(order),
                ] else ...[
                  _buildOrderProductsCard(context, order),
                  SizedBox(height: healthDp(context, 20)),
                  _buildDeliveryAddressSection(order),
                  SizedBox(height: healthDp(context, 20)),
                  DeliveryDetailPaymentSection(
                    order: order,
                    initiallyExpanded: true,
                  ),
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

  Widget _buildDeliveryAddressSection(OrderDetailModel order) {
    final awaiting = _isAwaitingDeposit(order);
    // 일반상품 결제대기중에도 배송지 변경 노출 (핑크 아웃라인)
    final showAddressChange = !awaiting || !order.isPrescriptionOrder;

    return DeliveryDetailAddressSection(
      order: order,
      deliveryMemo: _deliveryMemo,
      memoPresets: _deliveryMemoPresets,
      onMemoChanged: _onDeliveryMemoChanged,
      memoEditable: true,
      showChangeButton: showAddressChange,
      changeButtonPink: true,
      onChangeTap: _openDeliveryAddressChange,
      showSameDayShipNote: true,
    );
  }

  Widget _buildOrderProductsCard(
    BuildContext context,
    OrderDetailModel order,
  ) {
    if (!order.isPrescriptionOrder) {
      return DeliveryDetailGeneralProductsSection(
        order: order,
        onCancelTap: () => _cancelOrder(order),
      );
    }

    return DeliveryDetailReservationProductsCard(
      order: order,
      showChangeButton: !_isAwaitingDeposit(order),
      onChangeTap: () => _changeReservationTime(order),
      actions: [
        (
          label: '주문취소',
          onTap: () => _cancelOrder(order),
          style: DeliveryDetailProductActionStyle.outlineGray,
        ),
      ],
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
