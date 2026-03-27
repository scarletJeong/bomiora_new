import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

/// 리뷰 작성 화면
class ReviewWriteScreen extends StatefulWidget {
  final OrderDetailModel? orderDetail;
  final ReviewModel? initialReview;

  const ReviewWriteScreen({
    super.key,
    this.orderDetail,
    this.initialReview,
  });

  const ReviewWriteScreen.edit({
    super.key,
    required ReviewModel review,
  })  : orderDetail = null,
        initialReview = review;

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final _formKey = GlobalKey<FormState>();

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const String _kFont = 'Gmarket Sans TTF';

  int _score1 = 0;
  int _score2 = 0;
  int _score3 = 0;
  int _score4 = 0;
  int _weightLossKg = 1;

  final _positiveController = TextEditingController();
  final _negativeController = TextEditingController();
  final _moreController = TextEditingController();

  final List<File> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool get _isEditMode => widget.initialReview != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.initialReview;
    if (editing != null) {
      _score1 = editing.isScore1;
      _score2 = editing.isScore2;
      _score3 = editing.isScore3;
      _score4 = editing.isScore4;
      final w = editing.isOutageNum ?? 0;
      _weightLossKg = w < 1 ? 1 : (w > 50 ? 50 : w);
      _positiveController.text = editing.isPositiveReviewText ?? '';
      _negativeController.text = editing.isNegativeReviewText ?? '';
      _moreController.text = editing.isMoreReviewText ?? '';
      return;
    }

    final od = widget.orderDetail;
    if (od == null) {
      return;
    }
    _weightLossKg = 1;
    final items = od.products;
    debugPrint('📝 [리뷰 작성] odId=${od.odId} isPrescriptionOrder=${od.isPrescriptionOrder} 상품수=${items.length}');
    for (var i = 0; i < items.length; i++) {
      final p = items[i];
      debugPrint('   [$i] itId=${p.itId} itName=${p.itName} itSubject=${p.itSubject} ctOption=${p.ctOption}');
    }
  }

  @override
  void dispose() {
    _positiveController.dispose();
    _negativeController.dispose();
    _moreController.dispose();
    super.dispose();
  }

  Widget _orderProductThumb(String? rawUrl) {
    final url = ImageUrlHelper.getImageUrl(rawUrl);
    Widget fallback() => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.image_outlined, color: _kMuted),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  Widget _editReviewProductThumb(ReviewModel review) {
    Widget fallback() => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.image_outlined, color: _kMuted),
        );
    if (review.images.isEmpty) return fallback();
    final u = ImageUrlHelper.getReviewImageUrl(review.images.first);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        u,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  /// 섹션 제목 앞 세로 막대(| 느낌, 두께 2)
  Widget _barSectionTitle(
    String title, {
    String? trailing,
    Color? trailingColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: _kPink,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 16,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.2,
            ),
          ),
        ),
        if (trailing != null && trailing.isNotEmpty)
          Text(
            trailing,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: trailingColor ?? _kMuted,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _kFont, color: _kInk),
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(title: _isEditMode ? '리뷰수정' : '리뷰쓰기'),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
            children: [
              const SizedBox(height: 10),
              if (!_isEditMode) _buildProductSection() else _buildReviewProductSectionForEdit(),
              const SizedBox(height: 20),
              _buildWeightSection(),
              const SizedBox(height: 20),
              _buildSatisfactionSection(),
              const SizedBox(height: 20),
              _buildReviewTextSection(
                barTitle: '좋았던 점',
                requiredField: true,
                controller: _positiveController,
                hint: '직접 사용(복용)해보며 느낀 점과 만족스러웠던 점 어떤 분들께 추천하고 싶은지 함께 작성해주세요. (최소 20자)',
              ),
              const SizedBox(height: 20),
              _buildReviewTextSection(
                barTitle: '아쉬운 점',
                requiredField: true,
                controller: _negativeController,
                hint: '사용(복용)하면서 아쉬웠던 점과 개선되었으면 하는 부분이 있다면 알려주세요. (최소 20자)',
              ),
              const SizedBox(height: 20),
              _buildReviewTextSection(
                barTitle: '꿀팁',
                requiredField: false,
                controller: _moreController,
                hint: '사용(복용)하시면서 알게 된 꿀팁이나 효과적으로 활용하는 방법이 있다면 공유해주세요. (최소 20자)',
              ),
              const SizedBox(height: 20),
              _buildImageSection(),
              const SizedBox(height: 20),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSection() {
    final od = widget.orderDetail;
    if (od == null) return const SizedBox.shrink();
    final firstItem = od.products.isNotEmpty ? od.products.first : null;
    if (firstItem == null) return const SizedBox.shrink();

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barSectionTitle('주문 상품 정보'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Row(
              children: [
                _orderProductThumb(firstItem.imageUrl),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.itName,
                        style: const TextStyle(
                          fontFamily: _kFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '수량: ${firstItem.ctQty}${firstItem.ctOption != null && firstItem.ctOption!.isNotEmpty ? ' / ${firstItem.ctOption}' : ''}',
                        style: const TextStyle(
                          fontFamily: _kFont,
                          color: Color(0xFF898383),
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewProductSectionForEdit() {
    final review = widget.initialReview;
    if (review == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle('주문 상품 정보'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorder),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Row(
            children: [
              _editReviewProductThumb(review),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  review.itName ?? review.itId,
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle('감량 그래프', trailing: '(선택)', trailingColor: _kMuted),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '얼마나 감량하셨나요?',
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 12,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.32,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    '$_weightLossKg',
                    style: const TextStyle(
                      fontFamily: _kFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'kg',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _kPink,
            inactiveTrackColor: const Color(0xFFF6F6F6),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackShape: const RoundedRectSliderTrackShape(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: _weightLossKg.clamp(1, 50).toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (v) => setState(() => _weightLossKg = v.round().clamp(1, 50)),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: Color(0xFFA19E9E),
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '10kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: Color(0xFFA19E9E),
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '20kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '30kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '40kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '50kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSatisfactionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle(
          '상품 만족도',
          trailing: '*  필수',
          trailingColor: const Color(0xFFEF4444),
        ),
        const SizedBox(height: 10),
        _scoreRow('효과', _score1, (v) => setState(() => _score1 = v)),
        const SizedBox(height: 8),
        _scoreRow('가성비', _score2, (v) => setState(() => _score2 = v)),
        const SizedBox(height: 8),
        _scoreRow('향/맛', _score3, (v) => setState(() => _score3 = v)),
        const SizedBox(height: 8),
        _scoreRow('편리함', _score4, (v) => setState(() => _score4 = v)),
      ],
    );
  }

  Widget _scoreRow(String label, int score, ValueChanged<int> onChanged) {
    return Container(
      width: double.infinity,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(5, (index) {
              final on = index < score;
              return IconButton(
              icon: Icon(
                  on ? Icons.star : Icons.star_border,
                  color: _kPink,
                  size: 20,
              ),
                onPressed: () => onChanged(index + 1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              );
            }),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildReviewTextSection({
    required String barTitle,
    required bool requiredField,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle(
          barTitle,
          trailing: requiredField ? '*  필수' : '(선택)',
          trailingColor: requiredField ? const Color(0xFFEF4444) : _kMuted,
        ),
        const SizedBox(height: 10),
        Container(
          height: 120,
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorder),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLength: 3000,
            maxLines: null,
            style: const TextStyle(
              fontFamily: _kFont,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: _kInk,
            ),
            decoration: const InputDecoration(
              hintText: '',
              border: InputBorder.none,
              counterText: '',
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (requiredField && v.length < 20) {
                return '최소 20자 이상 입력해 주세요.';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${controller.text.length}/3,000자',
            style: const TextStyle(
              fontFamily: _kFont,
              color: _kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle('사진 업로드', trailing: '(선택)', trailingColor: _kMuted),
        const SizedBox(height: 10),
        Row(
          children: [
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: 76,
                height: 76,
                decoration: ShapeDecoration(
                  color: const Color(0x99D2D2D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: Colors.white),
                    SizedBox(height: 4),
                    Text(
                      '사진추가하기',
                    style: TextStyle(
                        fontFamily: _kFont,
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            ..._imageFiles.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(e.value, width: 76, height: 76, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: InkWell(
                        onTap: () => setState(() => _imageFiles.removeAt(e.key)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(
            fontFamily: _kFont,
            color: _kMuted,
            fontSize: 10,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontFamily: _kFont,
                  color: _kMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            height: 40,
            decoration: ShapeDecoration(
              color: _kPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: TextButton(
              onPressed: _isLoading ? null : _submitReview,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditMode ? '수정' : '등록',
                      style: const TextStyle(
                        fontFamily: _kFont,
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// 이미지 선택
  Future<void> _pickImage() async {
    if (_imageFiles.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 3장까지 첨부할 수 있습니다.')),
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

  /// 리뷰 제출
  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
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
      
      final currentOrderFirstItem = widget.orderDetail != null && widget.orderDetail!.products.isNotEmpty
          ? widget.orderDetail!.products.first
          : null;
      final editTarget = widget.initialReview;
      final itId = editTarget?.itId ?? currentOrderFirstItem?.itId;
      if (itId == null || itId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('상품 정보를 찾을 수 없습니다.')),
          );
        }
        return;
      }

      // 이미지 경로 리스트
      List<String> imagePaths = _imageFiles.map((file) => file.path).toList();
      
      if (_positiveController.text.trim().length < 20 ||
          _negativeController.text.trim().length < 20) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('좋았던 점/아쉬운 점은 각각 20자 이상 입력해 주세요.')),
          );
        }
        return;
      }

      // 작성/수정 공용 리뷰 모델 생성
      final review = ReviewModel(
        isId: editTarget?.isId,
        mbId: user.id,
        odId: editTarget?.odId ?? widget.orderDetail?.odId,
        itId: itId,
        isName: user.name,
        isScore1: _score1 == 0 ? 1 : _score1,
        isScore2: _score2 == 0 ? 1 : _score2,
        isScore3: _score3 == 0 ? 1 : _score3,
        isScore4: _score4 == 0 ? 1 : _score4,
        isRvkind: editTarget?.isRvkind ?? 'prescription',
        isRecommend: editTarget?.isRecommend ?? 'y',
        isPositiveReviewText: _positiveController.text,
        isNegativeReviewText: _negativeController.text.isNotEmpty 
            ? _negativeController.text 
            : null,
        isMoreReviewText: _moreController.text.isNotEmpty 
            ? _moreController.text 
            : null,
        images: imagePaths,
        isPayMthod: 'solo', // 내돈내산
        isOutageNum: _weightLossKg,
      );
      
      // API 호출
      final result = _isEditMode && editTarget?.isId != null
          ? await ReviewService.updateReview(editTarget!.isId!, review)
          : await ReviewService.createReview(review);
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? (_isEditMode ? '리뷰가 성공적으로 수정되었습니다.' : '리뷰가 성공적으로 작성되었습니다.'),
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          // 화면 닫기
          Navigator.pop(context, true); // true를 반환하여 새로고침 유도
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? (_isEditMode ? '리뷰 수정에 실패했습니다.' : '리뷰 작성에 실패했습니다.')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print(_isEditMode ? '리뷰 수정 오류: $e' : '리뷰 작성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '리뷰 수정 중 오류가 발생했습니다.' : '리뷰 작성 중 오류가 발생했습니다.'),
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

