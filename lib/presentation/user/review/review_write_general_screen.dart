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

/// 일반 상품 리뷰 (`it_kind` / `is_rvkind` general) — 본문은 `is_more_review_text` 만 사용, 세부 `is_score1~4` 는 0.
class ReviewWriteGeneralScreen extends StatefulWidget {
  final OrderDetailModel? orderDetail;
  final ReviewModel? initialReview;

  ReviewWriteGeneralScreen({
    super.key,
    required OrderDetailModel orderDetail,
  })  : orderDetail = orderDetail,
        initialReview = null;

  ReviewWriteGeneralScreen.edit({
    super.key,
    required ReviewModel review,
  })  : orderDetail = null,
        initialReview = review;

  bool get _isEditMode => initialReview != null;

  @override
  State<ReviewWriteGeneralScreen> createState() => _ReviewWriteGeneralScreenState();
}

class _ReviewWriteGeneralScreenState extends State<ReviewWriteGeneralScreen> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kInk = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const String _kFont = 'Gmarket Sans TTF';

  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  /// 0 = 만족도 미선택, 0.5~5(0.5 단위) = `total_is_score`
  double _score = 0;
  bool _isLoading = false;
  /// 카드 밖에 표시 (입력란 안에는 검증 문구 없음)
  String? _reviewBodyError;
  final List<File> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();

  late final VoidCallback _reviewTextListener;

  @override
  void initState() {
    super.initState();
    _reviewTextListener = () {
      if (!mounted) return;
      setState(() {
        if (_reviewBodyError != null && _reviewController.text.trim().length >= 20) {
          _reviewBodyError = null;
        }
      });
    };
    _reviewController.addListener(_reviewTextListener);

    final r = widget.initialReview;
    if (r != null) {
      _reviewController.text = r.isMoreReviewText ?? '';
      _score = _snapTotalRating((r.totalIsScore ?? 0).toDouble());
    }
  }

  @override
  void dispose() {
    _reviewController.removeListener(_reviewTextListener);
    _reviewController.dispose();
    super.dispose();
  }

  OrderItem? get _firstOrderItem =>
      widget.orderDetail != null && widget.orderDetail!.products.isNotEmpty
          ? widget.orderDetail!.products.first
          : null;

  ReviewModel? get _editReview => widget.initialReview;

  Future<void> _pickImage() async {
    if (_imageFiles.length >= 3) {
      return;
    }
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _imageFiles.add(File(image.path)));
  }

  Future<void> _submit() async {
    final item = _firstOrderItem;
    final edit = _editReview;
    if (widget._isEditMode) {
      if (edit == null || edit.isId == null) return;
    } else if (item == null) {
      return;
    }

    final text = _reviewController.text.trim();

    if (_score < 0.5) {
      return;
    }
    if (text.length < 20) {
      setState(() => _reviewBodyError = '최소 20자 이상 작성해주세요.');
      return;
    }
    if (text.length > 3000) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }

      final paths = _imageFiles.isNotEmpty
          ? _imageFiles.map((e) => e.path).toList()
          : (edit?.images ?? const <String>[]);

      final itIdValue = widget._isEditMode ? edit!.itId : item!.itId;
      final odIdValue = edit?.odId ?? widget.orderDetail?.odId;

      final review = ReviewModel(
        isId: edit?.isId,
        mbId: user.id,
        odId: odIdValue,
        itId: itIdValue,
        isName: user.name,
        isScore1: 0,
        isScore2: 0,
        isScore3: 0,
        isScore4: 0,
        totalIsScore: _snapTotalRating(_score),
        isRvkind: 'general',
        isRecommend: edit?.isRecommend ?? 'y',
        isPositiveReviewText: null,
        isNegativeReviewText: null,
        isMoreReviewText: text,
        images: paths,
        isPayMthod: 'solo',
      );

      final Map<String, dynamic> result;
      if (widget._isEditMode) {
        result = await ReviewService.updateReview(edit!.isId!, review);
      } else {
        result = await ReviewService.createReview(review);
      }

      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _firstOrderItem;
    final edit = _editReview;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Gmarket Sans TTF', color: _kInk),
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(title: widget._isEditMode ? '리뷰수정' : '리뷰쓰기'),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
            children: [
              const SizedBox(height: 10),
              _barSectionTitle('주문상품 정보'),
              const SizedBox(height: 10),
              _productCard(item, edit),
              const SizedBox(height: 20),
              _barSectionTitle(
                '상품 만족도',
                trailing: '*  필수',
                trailingColor: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 10),
              _scoreCard(),
              const SizedBox(height: 20),
              _barSectionTitle(
                '상품 리뷰',
                trailing: '*  필수',
                trailingColor: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 10),
              _reviewInputBlock(),
              const SizedBox(height: 20),
              _barSectionTitle('사진 업로드', trailing: '(선택)', trailingColor: _kMuted),
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
                          : Text(
                              widget._isEditMode ? '수정' : '등록',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
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

  /// 검정 세로 막대 + 제목(font w300), `trailing` 은 라벨 바로 뒤
  Widget _barSectionTitle(
    String title, {
    String? trailing,
    Color? trailingColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 1,
          height: 16,
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(0.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: _kFont,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.2,
                color: _kInk,
              ),
              children: [
                TextSpan(text: title),
                if (trailing != null && trailing.isNotEmpty)
                  TextSpan(
                    text: '  $trailing',
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: trailingColor ?? _kMuted,
                      letterSpacing: -0.6,
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _productThumbForEdit(ReviewModel r) {
    Widget fallback() => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFE9E9E9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.image_outlined, color: _kMuted),
        );
    if (r.images.isNotEmpty) {
      final u = ImageUrlHelper.getReviewImageUrl(r.images.first);
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
    final thumb = r.productImage?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      final u = ImageUrlHelper.getImageUrl(thumb);
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
    return fallback();
  }

  Widget _productCard(OrderItem? item, ReviewModel? edit) {
    if (item != null) {
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
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 80,
                height: 80,
                child: (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty)
                    ? Image.network(
                        ImageUrlHelper.getImageUrl(item.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE9E9E9),
                          child: const Icon(Icons.image_outlined, color: _kMuted),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE9E9E9),
                        child: const Icon(Icons.image_outlined, color: _kMuted),
                      ),
              ),
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
    if (edit != null) {
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
            _productThumbForEdit(edit),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                edit.itName ?? edit.itId,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -1.26),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  double _snapTotalRating(double raw) {
    if (raw <= 0) return 0.0;
    final c = raw.clamp(0.5, 5.0);
    return (c * 2).round() / 2.0;
  }

  IconData _totalStarIcon(double rating, int index) {
    final full = index + 1.0;
    final half = index + 0.5;
    if (rating >= full - 1e-9) return Icons.star_rounded;
    if (rating >= half - 1e-9) return Icons.star_half_rounded;
    return Icons.star_border_rounded;
  }

  Color _totalStarColor(double rating, int index) {
    final half = index + 0.5;
    return rating >= half - 1e-9 ? _kPink : const Color(0xFFD2D2D2);
  }

  Widget _scoreCard() {
    final display = _score < 0.5 ? '0.0' : _score.toStringAsFixed(1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Text(display, style: const TextStyle(color: _kPink, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            '받아본 상품은 어떠셨나요?',
            style: TextStyle(fontFamily: _kFont, fontSize: 12, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  width: 36,
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _totalStarIcon(_score, i),
                        color: _totalStarColor(_score, i),
                        size: 22,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _score = i + 0.5),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _score = i + 1.0),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        style: const TextStyle(
          fontFamily: _kFont,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: _kInk,
        ),
        decoration: const InputDecoration(
          hintText: '상품 리뷰를 작성해주세요. (최소 20자)',
          hintStyle: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w300),
          border: InputBorder.none,
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _reviewInputBlock() {
    final len = _reviewController.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewInputCard(),
        if (_reviewBodyError != null) ...[
          const SizedBox(height: 8),
          Text(
            _reviewBodyError!,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$len/3,000자',
            style: const TextStyle(color: _kMuted, fontSize: 10, fontWeight: FontWeight.w300),
          ),
        ),
      ],
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
