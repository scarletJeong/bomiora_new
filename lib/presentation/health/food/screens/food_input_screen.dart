import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../data/services/food_lens_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

/// 식사 기록 화면
class MealRecordScreen extends StatefulWidget {
  const MealRecordScreen({super.key});

  @override
  State<MealRecordScreen> createState() => _MealRecordScreenState();
}

class _MealRecordScreenState extends State<MealRecordScreen> {
  final ImagePicker _picker = ImagePicker();
  
  String? selectedMealType = '점심식사';
  final List<String> mealTypes = ['아침식사', '점심식사', '저녁식사', '간식'];
  
  // 선택된 음식 목록
  List<Map<String, dynamic>> selectedFoods = [];
  
  // FoodLens 관련
  bool _isFoodLensInitialized = false;
  bool _isRecognizing = false;
  File? _capturedImage;
  
  // 음식 검색
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeFoodLens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// FoodLens SDK 초기화
  Future<void> _initializeFoodLens() async {
    try {
      const apiKey = 'de5b3bf499c443c9acfb654ee93f7eaa';
      final success = await FoodLensService.initialize(apiKey: apiKey);
      setState(() {
        _isFoodLensInitialized = success;
      });
    } catch (e) {
      print('FoodLens 초기화 오류: $e');
    }
  }

  /// 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _recognizeFoodFromImage(File(image.path));
      }
    } catch (e) {
      _showError('갤러리에서 이미지를 가져오는데 실패했습니다: $e');
    }
  }

  /// 카메라로 이미지 촬영
  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _recognizeFoodFromImage(File(image.path));
      }
    } catch (e) {
      _showError('카메라로 사진을 촬영하는데 실패했습니다: $e');
    }
  }

  /// FoodLens로 음식 인식
  Future<void> _recognizeFoodFromImage(File imageFile) async {
    if (!_isFoodLensInitialized) {
      _showError('FoodLens SDK가 초기화되지 않았습니다.');
      return;
    }

    setState(() {
      _isRecognizing = true;
      _capturedImage = imageFile;
    });

    try {
      final result = await FoodLensService.recognizeFood(
        imagePath: imageFile.path,
      );

      if (result != null && mounted) {
        // 인식된 음식을 선택된 음식 목록에 추가
        setState(() {
          selectedFoods.add({
            'name': result['foodName'] ?? '인식된 음식',
            'calories': (result['calories'] ?? 0).toInt(),
            'carbs': result['carbs'] ?? 0.0,
            'protein': result['protein'] ?? 0.0,
            'fat': result['fat'] ?? 0.0,
            'recognized': true, // FoodLens로 인식된 음식 표시
          });
          _isRecognizing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['foodName']} 인식 완료!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isRecognizing = false;
        });
        _showError('음식을 인식할 수 없습니다.');
      }
    } catch (e) {
      setState(() {
        _isRecognizing = false;
      });
      _showError('음식 인식 실패: $e');
    }
  }

  /// 음식 검색 (임시 - 나중에 API로 교체)
  void _searchFoods(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // TODO: 실제 API로 음식 검색
    // 임시 데이터
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text == query) {
        setState(() {
          _searchResults = [
            {'name': '쇠고기 미역국(1인분)', 'calories': 45},
            {'name': '미역국(1인분)', 'calories': 35},
            {'name': '백합 미역국(1인분)', 'calories': 55},
          ].where((food) => 
            food['name'].toString().toLowerCase().contains(query.toLowerCase())
          ).toList();
          _isSearching = false;
        });
      }
    });
  }

  /// 음식 선택
  void _selectFood(Map<String, dynamic> food) {
    setState(() {
      selectedFoods.add({
        'name': food['name'],
        'calories': food['calories'],
        'recognized': false,
      });
      _searchController.clear();
      _searchResults = [];
    });
  }

  /// 음식 삭제
  void _removeFood(int index) {
    setState(() {
      selectedFoods.removeAt(index);
    });
  }

  /// 식사 기록 저장
  void _saveMealRecord() {
    if (selectedFoods.isEmpty) {
      _showError('음식을 하나 이상 추가해주세요.');
      return;
    }

    // TODO: API로 저장
    Navigator.pop(context, {
      'mealType': selectedMealType,
      'foods': selectedFoods,
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘 섭취한 음식을 등록해주세요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // 식사 종류 선택
            const Text(
              '식사',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedMealType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: mealTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedMealType = value;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // 먹은 음식 검색
            const Text(
              '먹은 음식',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '음식 이름을 검색하세요',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _searchFoods,
            ),
            
            // 검색 결과
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._searchResults.map((food) {
                return ListTile(
                  title: Text(food['name'] ?? ''),
                  subtitle: Text('${food['calories']} kcal'),
                  trailing: Radio<Map<String, dynamic>>(
                    value: food,
                    groupValue: null,
                    onChanged: (_) => _selectFood(food),
                  ),
                  onTap: () => _selectFood(food),
                );
              }),
            ],
            
            // 선택된 음식 목록
            if (selectedFoods.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '선택된 음식',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...selectedFoods.asMap().entries.map((entry) {
                final index = entry.key;
                final food = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: food['recognized'] == true 
                        ? Colors.blue 
                        : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  food['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (food['recognized'] == true) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${food['calories']} kcal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                        onPressed: () => _removeFood(index),
                      ),
                    ],
                  ),
                );
              }),
            ],
            
            const SizedBox(height: 24),
            
            // 사진 추가 섹션
            const Text(
              '사진 추가',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRecognizing ? null : _takePicture,
                    icon: _isRecognizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                    label: const Text('카메라'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRecognizing ? null : _pickImageFromGallery,
                    icon: _isRecognizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library),
                    label: const Text('갤러리'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (_capturedImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _capturedImage!,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // 등록 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveMealRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '등록',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

