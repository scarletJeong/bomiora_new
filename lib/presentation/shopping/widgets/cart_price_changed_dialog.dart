import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

const String cartPriceChangedMessage =
    '상품 금액이 변경되었습니다. 장바구니를 다시 확인해 주세요.';

Future<void> showCartPriceChangedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final dialogW = healthDp(dialogContext, 272);
      final radius = healthDp(dialogContext, 20);
      final padH = healthDp(dialogContext, 20);
      final titleFs = healthSp(dialogContext, 20);
      final bodyFs = healthSp(dialogContext, 14);
      final buttonFs = healthSp(dialogContext, 16);
      final buttonH = healthDp(dialogContext, 50);

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: dialogW,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    padH,
                    padH,
                    padH,
                    healthDp(dialogContext, 8),
                  ),
                  child: Text(
                    '안내',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: titleFs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, 0, padH, padH),
                  child: Text(
                    cartPriceChangedMessage,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: bodyFs,
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                ),
                SizedBox(
                  height: buttonH,
                  width: double.infinity,
                  child: Material(
                    color: const Color(0xFFFF5A8D),
                    child: InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Center(
                        child: Text(
                          '확인',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: buttonFs,
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
