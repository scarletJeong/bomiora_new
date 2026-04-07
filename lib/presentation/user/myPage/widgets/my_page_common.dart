import 'package:flutter/material.dart';

/// 마이페이지 프로필 — 분홍 테두리 원형 아바타 프레임 (77×77 내부)
class MyPageAvatarFrame extends StatelessWidget {
  const MyPageAvatarFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: const Color(0xFFFF5A8D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(45),
        ),
      ),
      child: Container(
        width: 77,
        height: 77,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(45),
          ),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// 마이페이지 공통 로딩 인디케이터 색
class MyPageLoadingIndicator extends StatelessWidget {
  const MyPageLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFFF3787),
      ),
    );
  }
}

abstract final class MyPageButtonStyles {
  static ButtonStyle pinkElevated({EdgeInsetsGeometry? padding}) {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFF5A8D),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: padding,
    );
  }
}

/// 마이페이지 메인 — 라인 + 화살표 메뉴 행
class MyPageLineMenuItem extends StatelessWidget {
  const MyPageLineMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.isLast = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: isLast ? 1 : 0.5,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 1,
                  height: 16,
                  color: const Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.44,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFF1A1A1A),
            ),
          ],
        ),
      ),
    );
  }
}
