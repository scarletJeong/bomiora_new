import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TesterSection extends StatefulWidget {
  const TesterSection({super.key});

  @override
  State<TesterSection> createState() => _TesterSectionState();
}

class _TesterSectionState extends State<TesterSection> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> testerItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTesterItems();
  }

  Future<void> _loadTesterItems() async {
    try {
      final items = await _apiService.getTesterItems();
      setState(() {
        testerItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 체험단 데이터가 없으면 섹션을 표시하지 않음
    if (testerItems.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[50]!,
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // 섹션 타이틀
          const Text(
            'BOMIORA PARTNERSHIP',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: '인기 체험단',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007FAE),
                  ),
                ),
                TextSpan(
                  text: ' 신청',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // 체험단 아이템들
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: testerItems.length > 5 ? 5 : testerItems.length,
                  itemBuilder: (context, index) {
                    final item = testerItems[index];
                    return _buildTesterCard(item);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTesterCard(Map<String, dynamic> item) {
    final bool isApplicable = item['applicable'] ?? true;
    
    return Container(
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
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              image: DecorationImage(
                image: NetworkImage(item['img'] ?? ''),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // 상품 정보
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품 설명
                  Text(
                    item['it_subject'] ?? '',
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
                    item['it_name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // 체험단 설명
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // 가격 정보
                  Row(
                    children: [
                      const Text(
                        'Price',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item['tr_price'] ?? 0}원',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item['it_cust_price'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 마감일
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '마감 ${item['end_date'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 신청 현황
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '신청 ${item['applied'] ?? 0}명',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Text(' / ', style: TextStyle(fontSize: 12)),
                      Text(
                        '모집 ${item['quota'] ?? 0}명',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 신청 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isApplicable ? () {
                        // 체험단 신청 페이지로 이동
                        print('Navigate to tester application: ${item['tr_no']}');
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApplicable 
                            ? const Color(0xFF007FAE) 
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isApplicable ? '체험단 신청하기' : '신청 마감',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
