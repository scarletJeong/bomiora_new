import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../data/services/food_lens_service.dart';

/// 음식 인식 화면
class FoodRecognitionScreen extends StatefulWidget {
  const FoodRecognitionScreen({super.key});

  @override
  State<FoodRecognitionScreen> createState() => _FoodRecognitionScreenState();
}

class _FoodRecognitionScreenState extends State<FoodRecognitionScreen> {
  bool _isLoading = false;
  bool _isInitialized = false;
  Map<String, dynamic>? _recognitionResult;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  /// FoodLens SDK 초기화
  Future<void> _initializeSDK() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // AccessToken은 AndroidManifest.xml의 meta-data로 설정됨
      // API Key 파라미터는 현재 사용하지 않지만 호환성을 위해 유지
      const apiKey = 'de5b3bf499c443c9acfb654ee93f7eaa';
      
      final success = await FoodLensService.initialize(apiKey: apiKey);
      
      setState(() {
        _isInitialized = success;
        _isLoading = false;
      });

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('FoodLens SDK 초기화에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('초기화 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognitionResult = null;
        });
        
        await _recognizeFood(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 카메라로 사진 촬영
  Future<void> _takePicture() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognitionResult = null;
        });
        
        await _recognizeFood(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 촬영 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 음식 인식
  Future<void> _recognizeFood(String imagePath) async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SDK가 초기화되지 않았습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recognitionResult = null;
    });

    try {
      final result = await FoodLensService.recognizeFood(
        imagePath: imagePath,
      );
      
      setState(() {
        _recognitionResult = result;
        _isLoading = false;
      });

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('음식을 인식할 수 없습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음식 인식 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('음식 인식'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SDK 초기화 상태
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isInitialized ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isInitialized ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isInitialized ? Icons.check_circle : Icons.warning,
                    color: _isInitialized ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isInitialized
                        ? 'FoodLens SDK 초기화 완료'
                        : 'FoodLens SDK 초기화 중...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isInitialized ? Colors.green[900] : Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 이미지 선택 버튼
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || !_isInitialized
                        ? null
                        : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리에서 선택'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || !_isInitialized
                        ? null
                        : _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('사진 촬영'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 선택된 이미지
            if (_selectedImage != null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 로딩 인디케이터
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            
            // 인식 결과
            if (_recognitionResult != null && !_isLoading) ...[
              _buildRecognitionResult(_recognitionResult!),
            ],
          ],
        ),
      ),
    );
  }

  /// 인식 결과 위젯
  Widget _buildRecognitionResult(Map<String, dynamic> result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '인식 결과',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // 음식명
          if (result['foodName'] != null)
            _buildInfoRow('음식명', result['foodName'].toString()),
          
          // 칼로리
          if (result['calories'] != null)
            _buildInfoRow('칼로리', '${result['calories']} kcal'),
          
          // 신뢰도
          if (result['confidence'] != null)
            _buildInfoRow(
              '신뢰도',
              '${(result['confidence'] as num * 100).toStringAsFixed(1)}%',
            ),
          
          // 영양정보
          if (result['carbs'] != null ||
              result['protein'] != null ||
              result['fat'] != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              '영양 정보',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (result['carbs'] != null)
              _buildInfoRow('탄수화물', '${result['carbs']}g'),
            if (result['protein'] != null)
              _buildInfoRow('단백질', '${result['protein']}g'),
            if (result['fat'] != null)
              _buildInfoRow('지방', '${result['fat']}g'),
          ],
        ],
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

