import 'package:flutter/material.dart';
import '../../../common/widgets/confirm_dialog.dart';

/// 주문 취소 / 수령 확인 등 주문 플로우용 다이얼로그.
class OrderFlowDialogs {
  OrderFlowDialogs._();

  static const Color _kPink = Color(0xFFFF5A8D);

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
  static Future<void> showOrderCancelSuccess(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 272,
            padding: const EdgeInsets.all(20),
            decoration: const ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              shadows: [
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
                  const Text(
                    '주문 취소',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '주문이 취소되었습니다.\n'
                    '자세한 내용은 주문 취소 페이지에서\n'
                    '확인해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: _kPink,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            '확인',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
