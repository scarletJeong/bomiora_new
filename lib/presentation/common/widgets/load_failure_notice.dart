import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 조회 실패 안내. 빈 목록 아이콘은 쓰지 않는다.
class LoadFailureNotice extends StatelessWidget {
  const LoadFailureNotice({
    super.key,
    required this.message,
    required this.onRetry,
    this.actionLabel = '다시 시도',
  });

  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 10),
        healthDp(context, 28),
        healthDp(context, 10),
        healthDp(context, 28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: const Color(0xFF898686),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          SizedBox(height: healthDp(context, 16)),
          SizedBox(
            width: double.infinity,
            height: healthDp(context, 44),
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A8D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                actionLabel,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
