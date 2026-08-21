import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/cart_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/review_service.dart';
import '../../../utils/delivery_tracker.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../customer_service/models/qa_inquiry_draft.dart';
import '../../customer_service/screens/qa_write_screen.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../shopping/screens/prescription_booking/prescription_profile_screen.dart';
import '../../shopping/utils/cart_navigation.dart';
import '../review/review_write_general_screen.dart';
import '../review/review_write_screen.dart';
import 'widgets/delivery_address_change_popup.dart';
import 'widgets/delivery_select_list.dart';
import 'widgets/detail/delivery_detail_address_section.dart';
import 'widgets/detail/delivery_detail_deposit_card.dart';
import 'widgets/detail/delivery_detail_general_products_section.dart';
import 'widgets/detail/delivery_detail_payment_section.dart';
import 'widgets/detail/delivery_detail_products_section.dart';
import 'widgets/detail/delivery_detail_reservation_products_card.dart';
import 'widgets/detail/delivery_detail_reservation_section.dart';
import 'widgets/detail/delivery_detail_section_style.dart';
import 'widgets/detail/delivery_detail_status_card.dart';
import 'widgets/order_flow_dialogs.dart';
import 'widgets/reservation_time_change_popup.dart';

/// 주문 상세 화면
class DeliveryDetailScreen extends StatefulWidget {
  final String orderNumber;

  /// 목록에서 넘기면 상세 API 전에 즉시 화면을 그릴 수 있음
  final OrderDetailModel? initialOrder;

  const DeliveryDetailScreen({
    super.key,
    required this.orderNumber,
    this.initialOrder,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  OrderDetailModel? _orderDetail;
  bool _isLoading = true;
  String _deliveryMemo = '';
  List<String> _reviewedItIds = const [];

  static const _deliveryMemoPresets = <String>[
    '부재시 경비실에 맡겨 주세요',
    '부재시 문 앞에 놓아주세요',
    '배송 전 연락 바랍니다',
    '직접 받겠습니다',
  ];

  static const Color _kInk = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    final preview = widget.initialOrder;
    if (preview != null) {
      _orderDetail = preview;
      _deliveryMemo = (preview.deliveryMessage ?? '').trim();
      _isLoading = false;
    }
    _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    final hasPreview = _orderDetail != null;
    if (!hasPreview) {
      setState(() => _isLoading = true);
    }

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final result = await OrderService.getOrderDetail(
        odId: widget.orderNumber,
        mbId: user.id,
      );

      if (result['success'] == true) {
        final order = result['order'] as OrderDetailModel;
        if (!mounted) return;
        setState(() {
          _orderDetail = order;
          _deliveryMemo = (order.deliveryMessage ?? '').trim();
          _isLoading = false;
        });
        // 리뷰 여부는 화면 표시 후 백그라운드에서
        if (_isCompletedStage(order)) {
          _loadReviewedItIds(user.id, order.odId);
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviewedItIds(String mbId, String odId) async {
    try {
      final check = await ReviewService.checkReviewExists(
        mbId: mbId,
        odId: odId,
      );
      if (!mounted) return;
      setState(() {
        _reviewedItIds =
            (check['reviewedItIds'] as List<String>?) ?? const <String>[];
      });
    } catch (_) {}
  }

  bool _canWriteReview(OrderDetailModel order) {
    return pendingReviewProducts(order, _reviewedItIds).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '주문 내역'),
        child: Material(
          color: Colors.white,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orderDetail == null
                  ? _buildErrorState()
                  : _buildOrderDetail(),
        ),
      ),
    );
  }

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

  Widget _buildOrderDetail() {
    final order = _orderDetail!;
    final isRx = order.isPrescriptionOrder;
    final awaiting = _isPaymentWaitingStage(order);
    final paid = _isPaidStage(order);
    final preparing = _isPreparingStage(order);
    final consultDone = _isConsultationDoneStage(order);
    final delivering = _isDeliveringStage(order);
    final completed = _isCompletedStage(order);
    final cancelled = _isCancelledStage(order);
    final canChangeAddress = !cancelled &&
        !completed &&
        !consultDone &&
        !delivering &&
        !preparing;
    final showDepositCard = awaiting &&
        (order.paymentMethod.contains('가상') ||
            (order.odBankAccount ?? '').trim().isNotEmpty);

    final gap = SizedBox(height: healthDp(context, 20));

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: healthDp(context, 27),
          right: healthDp(context, 27),
          top: healthDp(context, 20),
          bottom: healthDp(context, 48),
        ),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeliveryDetailStatusCard(
              order: order,
              step: _progressStep(order),
              labels: _progressLabels(order),
              isCancelled: cancelled,
            ),
            if (cancelled) ...[
              gap,
              DeliveryDetailPaymentSection(
                order: order,
                cancelled: true,
              ),
              gap,
              _buildProductsSection(order),
              gap,
              DeliveryDetailAddressSection(
                order: order,
                deliveryMemo: _deliveryMemo,
                memoPresets: _deliveryMemoPresets,
                memoEditable: false,
                showChangeButton: false,
              ),
              if (isRx) ...[
                gap,
                DeliveryDetailReservationSection(
                  order: order,
                  asHistory: true,
                  showConsultDoneBadge: true,
                  badgeLabel: '상담 전 취소',
                  titleAlign: TextAlign.left,
                  iconColor: DeliveryDetailSectionStyle.muted,
                ),
              ],
            ] else ...[
              if (showDepositCard) ...[
                gap,
                DeliveryDetailDepositCard(order: order),
              ],
              // 결제대기~상담완료: 예약+상품 합쳐진 카드
              if (isRx &&
                  !delivering &&
                  !completed &&
                  (awaiting || paid || preparing || consultDone)) ...[
                gap,
                if (consultDone) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: healthDp(context, 10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: const Color(0x19FF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '상담완료 후 배송준비중인 상태로\n배송지 변경 또는 취소가 어렵습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFFF5A8D),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.50,
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                ],
                DeliveryDetailReservationProductsCard(
                  order: order,
                  showChangeButton: !awaiting && !consultDone,
                  onChangeTap: _showReservationTimeChangeDialog,
                  asConsultDone: consultDone,
                  actions: _productActions(order),
                ),
                gap,
                DeliveryDetailAddressSection(
                  order: order,
                  deliveryMemo: _deliveryMemo,
                  memoPresets: _deliveryMemoPresets,
                  onMemoChanged:
                      canChangeAddress ? _onDeliveryMemoChanged : null,
                  memoEditable: canChangeAddress,
                  showChangeButton: canChangeAddress,
                  changeButtonPink: !awaiting,
                  onChangeTap: _changeDeliveryAddress,
                  showSameDayShipNote: paid || preparing,
                ),
                gap,
                DeliveryDetailPaymentSection(
                  order: order,
                  initiallyExpanded: awaiting,
                ),
              ]
              // 비대면 배송중·배송완료: 주문상품 > 결제 > 주소 > 진료예약내역
              else if (isRx && (delivering || completed)) ...[
                gap,
                _buildProductsSection(order),
                gap,
                DeliveryDetailPaymentSection(
                  order: order,
                  compact: completed,
                  initiallyExpanded: false,
                ),
                gap,
                DeliveryDetailAddressSection(
                  order: order,
                  deliveryMemo: _deliveryMemo,
                  memoPresets: _deliveryMemoPresets,
                  memoEditable: false,
                  showChangeButton: false,
                ),
                gap,
                DeliveryDetailReservationSection(
                  order: order,
                  asHistory: true,
                  showConsultDoneBadge: true,
                  titleAlign: TextAlign.left,
                  iconColor: DeliveryDetailSectionStyle.muted,
                ),
              ]
              // 일반상품 등
              else if (!completed) ...[
                gap,
                if (!isRx && preparing) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: healthDp(context, 10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: const Color(0x19FF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '배송준비중인 상태로\n배송지 변경 또는 취소가 어렵습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFFF5A8D),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        height: 1.50,
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                ],
                _buildProductsSection(order),
                gap,
                DeliveryDetailAddressSection(
                  order: order,
                  deliveryMemo: _deliveryMemo,
                  memoPresets: _deliveryMemoPresets,
                  onMemoChanged:
                      canChangeAddress ? _onDeliveryMemoChanged : null,
                  memoEditable: canChangeAddress,
                  showChangeButton: canChangeAddress,
                  changeButtonPink: true,
                  onChangeTap: _changeDeliveryAddress,
                  showSameDayShipNote: false,
                ),
                gap,
                DeliveryDetailPaymentSection(
                  order: order,
                  initiallyExpanded: awaiting,
                ),
              ] else ...[
                gap,
                _buildProductsSection(order),
                gap,
                DeliveryDetailPaymentSection(
                  order: order,
                  compact: true,
                ),
                gap,
                DeliveryDetailAddressSection(
                  order: order,
                  deliveryMemo: _deliveryMemo,
                  memoPresets: _deliveryMemoPresets,
                  memoEditable: false,
                  showChangeButton: false,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<String> _progressLabels(OrderDetailModel order) {
    // 결제대기중(가상계좌 등)만 5단계. 카드 등 즉시결제는 처음부터 4단계.
    if (_isPaymentWaitingStage(order)) {
      if (order.isPrescriptionOrder) {
        return const ['결제대기중', '결제완료', '상담완료', '배송중', '배송완료'];
      }
      return const ['결제대기중', '결제완료', '배송준비중', '배송중', '배송완료'];
    }
    if (order.isPrescriptionOrder) {
      return const ['결제완료', '상담완료', '배송중', '배송완료'];
    }
    return const ['결제완료', '배송준비중', '배송중', '배송완료'];
  }

  int _progressStep(OrderDetailModel order) {
    if (_isCancelledStage(order)) return 0;
    final labels = _progressLabels(order);
    final fourFromPaid = labels.length == 4 && labels.first == '결제완료';

    if (order.isPrescriptionOrder) {
      if (fourFromPaid) {
        if (_isCompletedStage(order)) return 3;
        if (_isDeliveringStage(order)) return 2;
        if (_isConsultationDoneStage(order)) return 1;
        return 0; // 결제완료
      }
      if (_isCompletedStage(order)) return 4;
      if (_isDeliveringStage(order)) return 3;
      if (_isConsultationDoneStage(order)) return 2;
      if (_isPaidStage(order) ||
          order.odStatus == '입금' ||
          order.odStatus == '준비') {
        return 1;
      }
      return 0;
    }

    if (fourFromPaid) {
      if (_isCompletedStage(order)) return 3;
      if (_isDeliveringStage(order)) return 2;
      if (_isPreparingStage(order)) return 1;
      return 0; // 결제완료
    }
    if (_isCompletedStage(order)) return 4;
    if (_isDeliveringStage(order)) return 3;
    if (_isPreparingStage(order)) return 2;
    if (_isPaidStage(order)) return 1;
    return 0;
  }

  Widget _buildProductsSection(OrderDetailModel order) {
    final actions = _productActions(order);
    if (!order.isPrescriptionOrder) {
      VoidCallback? onCancel;
      final rest = <
          ({
            String label,
            VoidCallback? onTap,
            DeliveryDetailProductActionStyle style,
          })>[];
      for (final a in actions) {
        if (a.label == '주문취소') {
          onCancel = a.onTap;
        } else {
          rest.add(a);
        }
      }
      return DeliveryDetailGeneralProductsSection(
        order: order,
        onCancelTap: onCancel,
        actions: rest,
      );
    }
    return DeliveryDetailProductsSection(
      order: order,
      actions: actions,
    );
  }

  List<
      ({
        String label,
        VoidCallback? onTap,
        DeliveryDetailProductActionStyle style,
      })> _productActions(OrderDetailModel order) {
    if (_isCancelledStage(order)) {
      if (order.isPrescriptionOrder) {
        return [
          (
            label: '다시 진료담기',
            onTap: _reAddPrescriptionToCart,
            style: DeliveryDetailProductActionStyle.outlinePink,
          ),
          (
            label: '처방 예약하기',
            onTap: _rebookPrescription,
            style: DeliveryDetailProductActionStyle.primary,
          ),
        ];
      }
      return [
        (
          label: '재주문하기',
          onTap: _reAddPrescriptionToCart,
          style: DeliveryDetailProductActionStyle.outlinePink,
        ),
      ];
    }

    if (_isCompletedStage(order)) {
      final actions = <({
        String label,
        VoidCallback? onTap,
        DeliveryDetailProductActionStyle style
      })>[
        (
          label: '1:1 문의',
          onTap: _openInquiry,
          style: DeliveryDetailProductActionStyle.outlinePink,
        ),
        (
          label: '배송조회',
          onTap: _trackDelivery,
          style: DeliveryDetailProductActionStyle.outlinePink,
        ),
      ];
      if (_canWriteReview(order)) {
        actions.add((
          label: '리뷰쓰기',
          onTap: _writeReviewFromDetail,
          style: DeliveryDetailProductActionStyle.primary,
        ));
      } else {
        actions.add((
          label: '다시 담기',
          onTap: _reAddPrescriptionToCart,
          style: DeliveryDetailProductActionStyle.primary,
        ));
      }
      return actions;
    }

    if (_isDeliveringStage(order)) {
      return [
        (
              label: '수령확인',
              onTap: _confirmPurchase,
          style: DeliveryDetailProductActionStyle.outlinePink,
            ),
        (
              label: '배송조회',
              onTap: _trackDelivery,
          style: DeliveryDetailProductActionStyle.primary,
        ),
      ];
    }

    if (_isConsultationDoneStage(order)) {
      return const [];
    }

    if (_isPreparingStage(order)) {
      return const [];
    }

    if (_isPaymentWaitingStage(order) || _isPaidStage(order)) {
      return [
        (
          label: '주문취소',
          onTap: _cancelOrder,
          style: DeliveryDetailProductActionStyle.outlineGray,
        ),
      ];
    }

    return const [];
  }

  bool _isCancelledStage(OrderDetailModel order) {
    return order.displayStatus.contains('취소') ||
        order.odStatus.contains('취소') ||
        order.displayStatus == '주문 취소' ||
        order.displayStatus == '주문취소';
  }

  bool _isPaymentWaitingStage(OrderDetailModel order) {
    return order.displayStatus == '결제대기중' || order.odStatus == '주문';
  }

  bool _isPaidStage(OrderDetailModel order) {
    if (_isPreparingStage(order) ||
        _isConsultationDoneStage(order) ||
        _isDeliveringStage(order) ||
        _isCompletedStage(order) ||
        _isCancelledStage(order)) {
      return false;
    }
    if (order.isPrescriptionOrder &&
        (order.odStatus == '입금' || order.odStatus == '준비')) {
      return true;
    }
    return order.displayStatus == '결제완료' || order.odStatus == '입금';
  }

  bool _isPreparingStage(OrderDetailModel order) {
    if (order.isPrescriptionOrder) return false;
    return order.displayStatus == '배송준비중' || order.odStatus == '준비';
  }

  bool _isConsultationDoneStage(OrderDetailModel order) {
    if (!order.isPrescriptionOrder) return false;
    if (_isDeliveringStage(order) ||
        _isCompletedStage(order) ||
        _isCancelledStage(order)) {
      return false;
    }
    if (order.isConsultationDone) return true;
    final display = order.displayStatus;
    return display == '상담완료' || display.contains('상담');
  }

  bool _isDeliveringStage(OrderDetailModel order) {
    return order.displayStatus == '배송중' || order.odStatus == '배송';
  }

  bool _isCompletedStage(OrderDetailModel order) {
    return order.displayStatus == '배송완료' || order.odStatus == '완료';
  }

  Future<void> _showReservationTimeChangeDialog() async {
    if (_orderDetail == null) return;
    if (_orderDetail!.reservationDate == null ||
        _orderDetail!.reservationTime == null) {
      return;
    }
    
    final orderIdToUse =
        widget.orderNumber.isNotEmpty ? widget.orderNumber : _orderDetail!.odId;
    
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

    if (result == true && mounted) _loadOrderDetail();
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
    if (ok && mounted) {
      // 목록 복귀 시 리로드되도록 결과 전달 + 상세도 갱신
      Navigator.pop(context, true);
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
      AppToastOverlay.show(
        context,
        '수령 확인되었습니다.',
      );
      // 목록 복귀 시 리로드되도록 결과 전달
      Navigator.pop(context, true);
    } else {
      AppToastOverlay.show(
        context,
        result['message']?.toString() ?? '수령확인에 실패했습니다.',
      );
    }
  }

  Future<void> _onDeliveryMemoChanged(String value) async {
    final next = value.trim();
    final prev = _deliveryMemo;
    if (next == prev || _orderDetail == null) return;

    setState(() => _deliveryMemo = next);

    final user = await AuthService.getUser();
    if (user == null) {
      if (mounted) setState(() => _deliveryMemo = prev);
      return;
    }

    final result = await OrderService.updateDeliveryMemo(
      odId: _orderDetail!.odId,
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
            DeliveryAddressChangePopup(
              orderId: _orderDetail!.odId,
              recipientName: _orderDetail!.recipientName,
              recipientPhone: _orderDetail!.recipientPhone,
              recipientAddress: _orderDetail!.recipientAddress,
              recipientAddressDetail: _orderDetail!.recipientAddressDetail,
            ),
          ],
        );
      },
    );
    if (result == true && mounted) _loadOrderDetail();
  }

  Future<void> _writeReviewFromDetail() async {
    if (_orderDetail == null) return;
    final user = await AuthService.getUser();
    if (user == null) return;

    final check = await ReviewService.checkReviewExists(
      mbId: user.id,
      odId: _orderDetail!.odId,
    );
    final reviewed =
        (check['reviewedItIds'] as List<String>?) ?? const <String>[];
    final pending = pendingReviewProducts(_orderDetail!, reviewed);

    if (!mounted) return;
    setState(() => _reviewedItIds = reviewed);

    if (pending.isEmpty) {
      AppToastOverlay.show(context, '작성할 리뷰가 없습니다.');
      return;
    }

    final isPrescription = _orderDetail!.isPrescriptionOrder;
    final bool? result;
    if (pending.length > 1) {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DeliverySelectList(
            orderDetail: _orderDetail!,
            pendingProducts: pending,
          ),
        ),
      );
    } else {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => isPrescription
              ? ReviewWriteScreen(
                  orderDetail: _orderDetail!,
                  selectedProducts: pending,
                )
              : ReviewWriteGeneralScreen(
                  orderDetail: _orderDetail!,
                  selectedProducts: pending,
                ),
        ),
      );
    }
    if (result == true && mounted) _loadOrderDetail();
  }

  Future<void> _openInquiry() async {
    final order = _orderDetail;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QaWriteScreen(
          prefilledDraft: order != null
              ? QaInquiryDraft.fromOrderDetail(order)
              : null,
        ),
      ),
    );
  }

  Future<void> _trackDelivery() async {
    if (_orderDetail == null) return;
    
    final companyName = _orderDetail!.deliveryCompany;
    final trackingNumber = _orderDetail!.trackingNumber;
    
    if (companyName == null || companyName.isEmpty) return;
    if (trackingNumber == null || trackingNumber.isEmpty) return;
    if (!DeliveryTracker.isSupported(companyName)) return;

    await DeliveryTracker.openTrackingPage(companyName, trackingNumber);
  }

  Future<({List<CartItem> items, List<int> ctIds})?> _addOrderProductsToCart({
    required bool selectForCheckout,
  }) async {
    final order = _orderDetail;
    if (order == null || order.products.isEmpty) {
      if (mounted) {
        AppToastOverlay.show(context, '다시 담을 상품 정보가 없습니다.');
      }
      return null;
    }

    final user = await AuthService.getUser();
    if (user == null) {
      if (mounted) {
        AppToastOverlay.show(context, '로그인이 필요합니다.');
      }
      return null;
    }

    final addedItems = <CartItem>[];
    final addedCtIds = <int>[];
    String? sharedOdId;

    for (final product in order.products) {
      final qty = product.ctQty > 0 ? product.ctQty : 1;
      final kind = (product.ctKind ?? product.itKind ?? 'prescription').trim();
      final price = product.ctPrice > 0
          ? product.ctPrice
          : (product.totalPrice > 0 ? product.totalPrice : 0);
      final optionText = (product.ctOption ?? '').trim();
      final optionId = (product.ioId ?? '').trim();

      final result = await CartService.addToCart(
        productId: product.itId,
        quantity: qty,
        price: price,
        optionId: optionId.isEmpty ? null : optionId,
        optionText: optionText.isEmpty ? null : optionText,
        optionPrice: product.ioPrice,
        ioType: product.ioType,
        odId: sharedOdId,
        ctKind: kind.isEmpty ? 'prescription' : kind,
        ctStatus: '쇼핑',
      );

      if (result['success'] != true) {
        if (mounted) {
          AppToastOverlay.show(
            context,
            result['message']?.toString() ?? '장바구니 담기에 실패했습니다.',
          );
        }
        return null;
      }

      final data = result['data'];
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final cartItem = CartItem.fromJson(map);
        addedItems.add(cartItem);
        final ctId = CartService.ctIdFromCartResponseData(map);
        if (ctId != null) addedCtIds.add(ctId);
        sharedOdId ??=
            (map['od_id'] ?? map['odId'])?.toString();
      }
    }

    if (selectForCheckout && addedCtIds.isNotEmpty) {
      await CartService.ensureCartItemsSelected(addedCtIds);
    }

    return (items: addedItems, ctIds: addedCtIds);
  }

  Future<void> _reAddPrescriptionToCart() async {
    final result = await _addOrderProductsToCart(selectForCheckout: false);
    if (result == null || !mounted) return;
    AppToastOverlay.show(context, '장바구니에 담았습니다.');
    await CartNavigation.openCart(
      context,
      prescriptionTab: _orderDetail?.isPrescriptionOrder ?? false,
    );
  }

  Future<void> _rebookPrescription() async {
    final result = await _addOrderProductsToCart(selectForCheckout: true);
    if (result == null || !mounted) return;

    final items = result.items;
    final main = items.firstWhere(
      (e) => !e.isSupplyAdd,
      orElse: () => items.first,
    );
    final bookingOptions = items
        .where((item) => !item.isSupplyAdd)
        .map(
          (item) => <String, dynamic>{
            'it_id': item.itId,
            'it_name': item.itName,
            'id': item.ioId ?? '',
            'name': item.ctOption.isNotEmpty ? item.ctOption : item.itName,
            'price': item.ioPrice ?? 0,
            'quantity': item.ctQty,
            'totalPrice': item.lineAmount,
            'ct_kind': item.ctKind,
          },
        )
        .toList();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionProfileScreen(
          productId: main.itId,
          productName: main.itName,
          selectedOptions: bookingOptions,
          cartCtIdsForCheckout: result.ctIds,
          checkoutCartItems: items,
        ),
            ),
    );
  }
}
