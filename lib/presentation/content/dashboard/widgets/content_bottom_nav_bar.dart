import 'package:flutter/material.dart';

/// 콘텐츠 대시보드·목록·상세에서 공통으로 쓰는 하단 핑크 탭 바 (Figma)
class ContentBottomNavBar extends StatelessWidget {
  const ContentBottomNavBar({super.key});

  static const Color _pink = Color(0xFFFF5A8D);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      clipBehavior: Clip.antiAlias,
      decoration: const ShapeDecoration(
        color: _pink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'HOME',
            style: TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '건강대시보드',
            style: TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '비대면 진료',
            style: TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '문진표',
            style: TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'MY PAGE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 6,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
