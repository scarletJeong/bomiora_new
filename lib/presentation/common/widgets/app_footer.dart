import 'package:flutter/material.dart';

/// 앱 전체에서 사용하는 Footer 위젯
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 회사 정보
          const Text(
            '(주)보미오라 | 대표: 정대진',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '사업자등록번호 356-87-02862',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '통신판매업신고번호 제2023-서울강남-02582',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '건강기능식품판매업신고 제2023-0138695호',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // 연락처 정보
          const Row(
            children: [
              Icon(
                Icons.phone,
                size: 16,
                color: Colors.black54,
              ),
              SizedBox(width: 8),
              Text(
                '전화 : 02-546-1031',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.email,
                size: 16,
                color: Colors.black54,
              ),
              SizedBox(width: 8),
              Text(
                '이메일 : official@bomiora.kr',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.black54,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '주소 : 서울 강남구 봉은사로 109, 6층(논현동)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

