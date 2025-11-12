import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/date_top_widget.dart';
import '../../../common/widgets/btn_record.dart';
import 'food_record_screen.dart';

/// 오늘의 식사 화면
class TodayDietScreen extends StatefulWidget {
  const TodayDietScreen({super.key});

  @override
  State<TodayDietScreen> createState() => _TodayDietScreenState();
}

class _TodayDietScreenState extends State<TodayDietScreen> {
  DateTime selectedDate = DateTime.now();
  
  // 임시 데이터 (나중에 API로 교체)
  int totalCalories = 1500;
  Map<String, int> mealCalories = {
    '아침식사': 400,
    '점심식사': 500,
    '저녁식사': 450,
    '간식': 150,
  };
  
  List<Map<String, dynamic>> mealRecords = [
    {
      'mealType': '점심식사',
      'foods': [
        {'name': '잡곡밥(150g)', 'calories': 230},
        {'name': '불고기(70g)', 'calories': 180},
        {'name': '쌈채(깻잎, 상추)', 'calories': 15},
        {'name': '김치(50g)', 'calories': 15},
        {'name': '된장찌개', 'calories': 60},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '식사 기록',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: Column(
        children: [
          // 날짜 선택 위젯
          DateTopWidget(
            selectedDate: selectedDate,
            onDateChanged: (date) {
              setState(() {
                selectedDate = date;
              });
              // 날짜 변경 시 데이터 다시 로드
              _loadMealData();
            },
          ),
          
          // 메인 콘텐츠
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 총 칼로리 표시
                  Container(

                    child: Column(
                      children: [
                        const Text(
                          '오늘 총 섭취 칼로리',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalCalories kcal',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF3787),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 식사별 칼로리
                  _buildMealTypeSection('아침식사', mealCalories['아침식사'] ?? 0),
                  const SizedBox(height: 16),
                  _buildMealTypeSection('점심식사', mealCalories['점심식사'] ?? 0),
                  const SizedBox(height: 16),
                  _buildMealTypeSection('저녁식사', mealCalories['저녁식사'] ?? 0),
                  const SizedBox(height: 16),
                  _buildMealTypeSection('간식', mealCalories['간식'] ?? 0),
                  
                  const SizedBox(height: 24),
                  
                  // 기록된 식사 목록
                  if (mealRecords.isNotEmpty) ...[
                    const Text(
                      '기록된 식사',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...mealRecords.map((record) => _buildMealRecordCard(record)),
                  ],
                ],
              ),
            ),
          ),
          
          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BtnRecord(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MealRecordScreen(),
                  ),
                ).then((_) {
                  // 기록 후 데이터 새로고침
                  _loadMealData();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSection(String mealType, int calories) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          mealType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$calories / kcal',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMealRecordCard(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record['mealType'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...(record['foods'] as List).map((food) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    food['name'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Row(
                    children: [
                      Text(
                        '${food['calories'] ?? 0}kcal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.grey,
                        onPressed: () {
                          // 삭제 기능 (나중에 구현)
                          setState(() {
                            mealRecords.remove(record);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _loadMealData() {
    // TODO: API로 데이터 가져오기
    setState(() {
      // 데이터 새로고침
    });
  }
}

