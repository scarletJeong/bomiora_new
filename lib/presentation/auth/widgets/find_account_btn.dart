import 'package:flutter/material.dart';

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
            height: 40,
            child: OutlinedButton(
              onPressed: onPasswordFind,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '비밀번호 찾기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF898686),
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFFF5A8D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '로그인하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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

