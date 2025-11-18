import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';
import '../../../data/services/auth_service.dart';

/// 리뷰 수정 화면
class ReviewEditScreen extends StatefulWidget {
  final ReviewModel review;
  
  const ReviewEditScreen({
    super.key,
    required this.review,
  });

  @override
  State<ReviewEditScreen> createState() => _ReviewEditScreenState();
}

class _ReviewEditScreenState extends State<ReviewEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // 평점
  late int _score1; // 효과
  late int _score2; // 가성비
  late int _score3; // 맛/향
  late int _score4; // 편리함
  
  // 추천 여부
  late bool _recommend;
  
  // 리뷰 내용
  late TextEditingController _positiveController;
  late TextEditingController _negativeController;
  late TextEditingController _moreController;
  
  // 이미지
  List<File> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();
  
  // 로딩
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // 기존 리뷰 데이터로 초기화
    _score1 = widget.review.isScore1;
    _score2 = widget.review.isScore2;
    _score3 = widget.review.isScore3;
    _score4 = widget.review.isScore4;
    _recommend = widget.review.isRecommend == 'y';
    
    _positiveController = TextEditingController(
      text: widget.review.isPositiveReviewText ?? '',
    );
    _negativeController = TextEditingController(
      text: widget.review.isNegativeReviewText ?? '',
    );
    _moreController = TextEditingController(
      text: widget.review.isMoreReviewText ?? '',
    );
  }

  @override
  void dispose() {
    _positiveController.dispose();
    _negativeController.dispose();
    _moreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            '리뷰 수정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 평점 섹션
              _buildScoreSection(),
              const SizedBox(height: 24),
              
              // 추천 여부
              _buildRecommendSection(),
              const SizedBox(height: 24),
              
              // 리뷰 내용 섹션
              _buildReviewContentSection(),
              const SizedBox(height: 24),
              
              // 이미지 업로드 섹션
              _buildImageSection(),
              const SizedBox(height: 32),
              
              // 수정 완료 버튼
              _buildSubmitButton(),
              const SizedBox(height: 32),
              
              const SizedBox(height: 300),
              
              // Footer
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// 평점 섹션
  Widget _buildScoreSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상품 평가',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildScoreItem('효과', _score1, (value) => setState(() => _score1 = value)),
          const SizedBox(height: 12),
          _buildScoreItem('가성비', _score2, (value) => setState(() => _score2 = value)),
          const SizedBox(height: 12),
          _buildScoreItem('맛/향', _score3, (value) => setState(() => _score3 = value)),
          const SizedBox(height: 12),
          _buildScoreItem('편리함', _score4, (value) => setState(() => _score4 = value)),
        ],
      ),
    );
  }

  /// 평점 항목
  Widget _buildScoreItem(String label, int score, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < score ? Icons.star : Icons.star_border,
                color: const Color(0xFFFF4081),
                size: 28,
              ),
              onPressed: () => onChanged(index + 1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            );
          }),
        ),
      ],
    );
  }

  /// 추천 여부 섹션
  Widget _buildRecommendSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '이 상품을 추천하시나요?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              _buildRecommendButton(true),
              const SizedBox(width: 8),
              _buildRecommendButton(false),
            ],
          ),
        ],
      ),
    );
  }

  /// 추천 버튼
  Widget _buildRecommendButton(bool value) {
    final isSelected = _recommend == value;
    return GestureDetector(
      onTap: () => setState(() => _recommend = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4081) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4081) : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          value ? '네 👍' : '아니오 👎',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  /// 리뷰 내용 섹션
  Widget _buildReviewContentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '리뷰 내용',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // 좋았던 점
          TextFormField(
            controller: _positiveController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '좋았던 점',
              hintText: '어떤 점이 좋았나요?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF4081)),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '좋았던 점을 입력해주세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 아쉬운 점
          TextFormField(
            controller: _negativeController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '아쉬운 점 (선택)',
              hintText: '아쉬운 점이 있다면 알려주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF4081)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 꿀팁
          TextFormField(
            controller: _moreController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '꿀팁 (선택)',
              hintText: '다른 분들께 꿀팁을 공유해주세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF4081)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 이미지 업로드 섹션
  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '사진 첨부 (선택)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${_imageFiles.length}/10',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 이미지 그리드
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 이미지 추가 버튼
              if (_imageFiles.length < 10)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.grey[600]),
                        const SizedBox(height: 4),
                        Text(
                          '사진 추가',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 선택된 이미지들
              ..._imageFiles.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(file),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// 수정 완료 버튼
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitReview,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              '수정 완료',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  /// 이미지 선택
  Future<void> _pickImage() async {
    if (_imageFiles.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 10장까지 첨부할 수 있습니다.')),
      );
      return;
    }
    
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _imageFiles.add(File(image.path));
        });
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 선택할 수 없습니다.')),
        );
      }
    }
  }

  /// 이미지 제거
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  /// 리뷰 수정 제출
  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (widget.review.isId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 ID를 찾을 수 없습니다.')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 로그인된 사용자 정보 가져오기
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }
      
      // 이미지 경로 리스트
      List<String> imagePaths = _imageFiles.map((file) => file.path).toList();
      
      // 수정된 리뷰 모델 생성
      final updatedReview = ReviewModel(
        isId: widget.review.isId,
        mbId: user.id,
        itId: widget.review.itId,
        isName: user.name ?? user.id,
        isScore1: _score1,
        isScore2: _score2,
        isScore3: _score3,
        isScore4: _score4,
        isRvkind: widget.review.isRvkind,
        isRecommend: _recommend ? 'y' : 'n',
        isPositiveReviewText: _positiveController.text,
        isNegativeReviewText: _negativeController.text.isNotEmpty 
            ? _negativeController.text 
            : null,
        isMoreReviewText: _moreController.text.isNotEmpty 
            ? _moreController.text 
            : null,
        images: imagePaths,
      );
      
      // API 호출
      final result = await ReviewService.updateReview(
        widget.review.isId!,
        updatedReview,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '리뷰가 성공적으로 수정되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 화면 닫기
          Navigator.pop(context, true); // true를 반환하여 새로고침 유도
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '리뷰 수정에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('리뷰 수정 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리뷰 수정 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

