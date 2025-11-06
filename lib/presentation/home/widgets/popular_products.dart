import 'package:flutter/material.dart';

class PopularProducts extends StatefulWidget {
  const PopularProducts({
    super.key,
  });

  @override
  State<PopularProducts> createState() => _PopularProductsState();
}

class _PopularProductsState extends State<PopularProducts> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // 임시로 로딩 완료 처리
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = now.month;
    final week = _getWeekOfMonth(now);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 섹션 타이틀
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${month}월 ${week}주차 ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const TextSpan(
                  text: '인기순위',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007FAE),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '보미오라의 베스트 상품을 소개합니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          
          // 상품 그리드
          isLoading
              ? const Center(
                  child: Text('상품을 불러오는 중입니다...'),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: 4, // 임시로 4개 고정
                  itemBuilder: (context, index) {
                    return _buildProductCard(index + 1);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildProductCard(int rank) {
    return GestureDetector(
      onTap: () {
        // 상품 상세 페이지로 이동
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  image: DecorationImage(
                    image: const NetworkImage('https://via.placeholder.com/150'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    // 순위 배지
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007FAE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$rank위',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 상품 정보
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상품 설명
                    Text(
                      '상품 설명 $rank',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // 상품명
                    Text(
                      '상품명 $rank',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // 가격 정보
                    Row(
                      children: [
                        if (rank % 2 == 0) ...[
                          Text(
                            '${rank * 10}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            '${(rank * 10000).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // 리뷰 정보
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          (4.0 + rank * 0.1).toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${rank * 25})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getWeekOfMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final daysDifference = date.difference(firstDayOfMonth).inDays;
    return (daysDifference / 7).ceil();
  }
}
