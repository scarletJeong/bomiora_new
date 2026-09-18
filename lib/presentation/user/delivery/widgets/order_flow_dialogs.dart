import 'package:flutter/material.dart';

import '../../../../data/models/delivery/delivery_model.dart';
import '../../../../data/services/delivery_service.dart';
import '../../../../data/services/refund_account_service.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import 'delivery_status_filter_bar.dart';
import 'refund_account_popup.dart';

/// 주문 취소 / 수령 확인 등 주문 플로우용 다이얼로그.
class OrderFlowDialogs {
  OrderFlowDialogs._();

  static const Color _kPink = Color(0xFFFF5A8D);

  static bool _isVirtualAccountPayment(String paymentMethod) {
    return paymentMethod.contains('가상');
  }

  static Future<OrderDetailModel?> _loadOrderDetail({
    required String odId,
    required String mbId,
    OrderDetailModel? orderDetail,
  }) async {
    if (orderDetail != null) return orderDetail;
    final detailResult = await OrderService.getOrderDetail(
      odId: odId,
      mbId: mbId,
    );
    if (detailResult['success'] == true &&
        detailResult['order'] is OrderDetailModel) {
      return detailResult['order'] as OrderDetailModel;
    }
    return null;
  }

  /// 가상계좌 **입금 후**만 환불계좌 입력 → 취소 확인 → API.
  /// 입금 전·그 외 결제: 취소 확인 → API. 성공 시 true.
  static Future<bool> runOrderCancelFlow(
    BuildContext context, {
    required String odId,
    required String mbId,
    OrderDetailModel? orderDetail,
  }) async {
    final detail = await _loadOrderDetail(
      odId: odId,
      mbId: mbId,
      orderDetail: orderDetail,
    );
    final paymentMethod = detail?.paymentMethod ?? '';
    final needRefundAccount = _isVirtualAccountPayment(paymentMethod) &&
        detail != null &&
        !detail.isAwaitingVirtualDeposit;

    RefundAccountInput? refundInput;
    if (needRefundAccount) {
      if (!context.mounted) return false;
      refundInput = await RefundAccountPopup.show(context, mbId: mbId);
      if (refundInput == null) return false;

      await RefundAccountService.save(
        mbId: mbId,
        refundBank: refundInput.bank,
        refundAccountDigits: refundInput.accountDigits,
        refundHolder: refundInput.holder,
      );
    }

    if (!context.mounted) return false;
    final confirmed = await showOrderCancelConfirm(context);
    if (confirmed != true) return false;

    final result = await OrderService.cancelOrder(
      odId: odId,
      mbId: mbId,
      refundBank: refundInput?.bank,
      refundAccount: refundInput?.accountDigits,
      refundHolder: refundInput?.holder,
    );

    if (!context.mounted) return false;
    if (result['success'] == true) {
      await showOrderCancelSuccess(
        context,
        cancelRequested: result['cancelRequested'] == true,
      );
      return true;
    }

    AppToastOverlay.show(
      context,
      result['message']?.toString() ?? '주문 취소에 실패했습니다.',
    );
    return false;
  }

  /// 취소 완료 후 해당 주문의 취소 상세로 이동 (결제완료 화면은 스택에서 제거).
  static Future<void> openCancelledOrderPage(
    BuildContext context, {
    required String odId,
    required bool isPrescription,
  }) {
    return Navigator.pushNamedAndRemoveUntil(
      context,
      '/order',
      (route) => route.isFirst,
      arguments: {
        'status': 'cancelled',
        'openOdId': odId,
        'productType': isPrescription
            ? DeliveryProductType.prescription
            : DeliveryProductType.general,
      },
    );
  }

  /// 1단계: 취소 확인 → true == 확인
  static Future<bool> showOrderCancelConfirm(BuildContext context) {
    return ConfirmDialog.show(
      context,
      title: '주문 취소',
      message: '주문을 취소하시겠습니까?',
      cancelText: '취소',
      confirmText: '확인',
      width: 272,
      showDivider: false,
    );
  }

  /// 2단계: 취소 완료 안내 (확인 한 번)
  static Future<void> showOrderCancelSuccess(
    BuildContext context, {
    bool cancelRequested = false,
  }) {
    final pad = healthDp(context, 20);
    final radius = healthDp(context, 20);
    final titleSize = healthSp(context, 20);
    final bodySize = healthSp(context, 14);
    final btnRadius = healthDp(context, 10);
    final btnPadV = healthDp(context, 10);
    final btnFont = healthSp(context, 16);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: healthDp(ctx, 272),
            padding: EdgeInsets.all(pad),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 8.14,
                  offset: Offset(0, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '주문 취소',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: healthDp(ctx, 20)),
                  Text(
                    cancelRequested
                        ? '취소 요청이 접수되었습니다.\n'
                            '환불은 관리자 확인 후 처리됩니다.\n'
                            '자세한 내용은 주문 취소 페이지에서\n'
                            '확인해 주세요.'
                        : '주문이 취소되었습니다.\n'
                            '자세한 내용은 주문 취소 페이지에서\n'
                            '확인해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: bodySize,
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                  SizedBox(height: healthDp(ctx, 20)),
                  Material(
                    color: _kPink,
                    borderRadius: BorderRadius.circular(btnRadius),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(btnRadius),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: btnPadV),
                        child: Center(
                          child: Text(
                            '확인',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: btnFont,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 수령(배송) 확인
  static Future<bool> showReceiptConfirm(BuildContext context) {
    return ConfirmDialog.show(
      context,
      title: '수령 확인',
      message: '수령 확인 시 주문이 완료됩니다. \n수령 확인하시겠습니까?',
      cancelText: '취소',
      confirmText: '확인',
      width: 272,
      showDivider: false,
    );
  }
}
