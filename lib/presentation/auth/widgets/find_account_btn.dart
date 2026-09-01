import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 아이디 찾기 결과 하단 — 비밀번호 찾기 / 로그인하기
class FindAccountResultActions extends StatelessWidget {
  const FindAccountResultActions({
    super.key,
    required this.onPasswordFind,
    required this.onLogin,
  });

  final VoidCallback onPasswordFind;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: healthDp(context, 40),
            child: OutlinedButton(
              onPressed: onPasswordFind,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  width: healthDp(context, 0.5),
                  color: const Color(0xFFD2D2D2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '비밀번호 찾기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF898686),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 20)),
        Expanded(
          child: SizedBox(
            height: healthDp(context, 40),
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFFF5A8D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '로그인하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
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
