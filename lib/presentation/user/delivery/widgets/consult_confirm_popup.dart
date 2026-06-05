import 'package:flutter/material.dart';

import '../../../health/health_common/health_responsive_scale.dart';

/// 교환/환불 신청 후 상담 예약 접수 확인 팝업
class ConsultConfirmPopup {
  ConsultConfirmPopup._();

  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _muted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5A8D);

  static String formatMessage(DateTime date, String timeHm) {
    final parts = timeHm.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return '${date.month}월 ${date.day}일 $h시 ${m.toString().padLeft(2, '0')}분\n'
        '상담 예약이 접수되었습니다';
  }

  /// 확인 탭 시 true, 취소 시 false
  static Future<bool> show(
    BuildContext context, {
    required DateTime reservationDate,
    required String reservationTime,
  }) {
    final message = formatMessage(reservationDate, reservationTime);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final w = healthDp(ctx, 272);
        final radius = healthDp(ctx, 20);
        final btnH = healthDp(ctx, 50);
        final pad = healthDp(ctx, 20);

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: healthDp(ctx, 24)),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                width: w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 8.14,
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                        child: Column(
                          children: [
                            Text(
                              '상담 예약 확인',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ink,
                                fontSize: healthSp(ctx, 20),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: healthDp(ctx, 20)),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _muted,
                                fontSize: healthSp(ctx, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1.57,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: btnH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () => Navigator.pop(ctx, false),
                                  child: Center(
                                    child: Text(
                                      '취소',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: healthSp(ctx, 16),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Material(
                                color: _pink,
                                child: InkWell(
                                  onTap: () => Navigator.pop(ctx, true),
                                  child: Center(
                                    child: Text(
                                      '확인',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: healthSp(ctx, 16),
                                        fontFamily: 'Gmarket Sans TTF',
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
                    ],
                  ),
                ),
            ),
          ),
        );
      },
    ).then((v) => v == true);
  }
}
