import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar.dart';

class ReviewWriteGeneralScreen extends StatefulWidget {
  final OrderDetailModel orderDetail;

  const ReviewWriteGeneralScreen({
    super.key,
    required this.orderDetail,
  });

  @override
  State<ReviewWriteGeneralScreen> createState() => _ReviewWriteGeneralScreenState();
}

class _ReviewWriteGeneralScreenState extends State<ReviewWriteGeneralScreen> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);

  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  int _score = 5;
  bool _isLoading = false;
  List<File> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  OrderItem? get _firstItem => widget.orderDetail.products.isNotEmpty ? widget.orderDetail.products.first : null;

  Future<void> _pickImage() async {
    if (_imageFiles.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 3장까지 첨부할 수 있습니다.')),
      );
      return;
    }
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _imageFiles.add(File(image.path)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _firstItem;
    if (item == null) return;

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      final review = ReviewModel(
        mbId: user.id,
        odId: widget.orderDetail.odId,
        itId: item.itId,
        isName: user.name,
        isScore1: _score,
        isScore2: _score,
        isScore3: _score,
        isScore4: _score,
        isRvkind: 'general',
        isRecommend: 'y',
        isPositiveReviewText: _reviewController.text.trim(),
        images: _imageFiles.map((e) => e.path).toList(),
        isPayMthod: 'solo',
      );

      final result = await ReviewService.createReview(review);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '리뷰가 등록되었습니다.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '리뷰 등록에 실패했습니다.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _firstItem;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(title: '리뷰쓰기'),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
            children: [
              const SizedBox(height: 10),
              _title('주문상품', '정보'),
              const SizedBox(height: 10),
              _productCard(item),
              const SizedBox(height: 20),
              _titleWithRequired('상품', '만족도'),
              const SizedBox(height: 10),
              _scoreCard(),
              const SizedBox(height: 20),
              _titleWithRequired('상품', '리뷰'),
              const SizedBox(height: 10),
              _reviewInputCard(),
              const SizedBox(height: 20),
              _titleOptional('사진', '업로드'),
              const SizedBox(height: 10),
              _imageSection(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD2D2D2), width: 0.5),
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('취소', style: TextStyle(color: _kMuted, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPink,
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('등록', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String bold, String light) {
    return Row(
      children: [
        Text(bold, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -1.44)),
        const SizedBox(width: 5),
        Text(light, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: -1.76)),
      ],
    );
  }

  Widget _titleWithRequired(String light, String bold) {
    return Row(
      children: [
        Text(light, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: -1.44)),
        const SizedBox(width: 5),
        Text(bold, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -1.76)),
        const SizedBox(width: 5),
        const Text('*  필수', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w300, letterSpacing: -1.32)),
      ],
    );
  }

  Widget _titleOptional(String bold, String light) {
    return Row(
      children: [
        Text(bold, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -1.44)),
        const SizedBox(width: 5),
        Text(light, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: -1.76)),
        const SizedBox(width: 5),
        const Text('( 선택 )', style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w300, letterSpacing: -1.32)),
      ],
    );
  }

  Widget _productCard(OrderItem? item) {
    if (item == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE9E9E9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.image_outlined, color: _kMuted),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -1.26)),
                const SizedBox(height: 10),
                Text(
                  item.ctOption?.isNotEmpty == true ? item.ctOption! : '옵션 없음',
                  style: const TextStyle(color: Color(0xFF898383), fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard() {
    return Container(
      width: 321,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          const Text('받아본 상품은 어떠셨나요?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final on = i < _score;
              return IconButton(
                onPressed: () => setState(() => _score = i + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(on ? Icons.star : Icons.star_border, color: _kPink, size: 22),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _reviewInputCard() {
    return Container(
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
        controller: _reviewController,
        maxLength: 3000,
        maxLines: null,
        decoration: const InputDecoration(
          hintText: '상품 리뷰를 작성해주세요. (최소 20자)',
          hintStyle: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w300),
          border: InputBorder.none,
          counterText: '',
        ),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.length < 20) return '최소 20자 이상 작성해주세요.';
          return null;
        },
      ),
    );
  }

  Widget _imageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    Text('사진추가하기', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
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
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
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
          style: TextStyle(color: _kMuted, fontSize: 10, fontWeight: FontWeight.w300),
        ),
      ],
    );
  }
}

