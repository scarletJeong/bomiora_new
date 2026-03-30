import 'package:flutter/material.dart';

class NoticeSection extends StatelessWidget {
  const NoticeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 191),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x26E4BDC2),
          ),
          borderRadius: BorderRadius.circular(0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 33),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 2,
                  height: 28,
                  color: const Color(0xFF28171A),
                ),
                const SizedBox(width: 6),
                const Text(
                  '공지사항',
                  style: TextStyle(
                    color: Color(0xFF28171A),
                    fontSize: 20,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5A8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: const Text(
                    '+ More',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NoticeRow(
              title: '[공지] 보미오라 4월 공지사항 안내',
              date: '2024.04.22',
            ),
            _NoticeRow(
              title: '[공지] 보미 다이어트한 신제품 출시 기념 공지사항 …',
              date: '2024.04.20',
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final String title;
  final String date;

  const _NoticeRow({
    required this.title,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: Color(0x19E4BDC2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF28171A),
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.33,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            date,
            style: const TextStyle(
              color: Color(0x665B3F43),
              fontSize: 10,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
