import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

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
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: _kFont),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: _kFont),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: _kFont, color: _kInk),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: widget._isEditMode ? '리뷰수정' : '리뷰쓰기',
              titleFontSize: healthSp(context, 18),
              leadingIconSize: healthDp(context, 24),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.only(
                  left: healthDp(context, 27),
                  right: healthDp(context, 27),
                  bottom: healthDp(context, 20),
                ),
                children: [
                  SizedBox(height: healthDp(context, 10)),
                  _barSectionTitle(context, '주문상품 정보'),
                  SizedBox(height: healthDp(context, 10)),
                  _productCard(context, item, edit),
                  SizedBox(height: healthDp(context, 20)),
                  _barSectionTitle(
                    context,
                    '상품 만족도',
                    trailing: '*  필수',
                    trailingColor: const Color(0xFFEF4444),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  _scoreCard(context),
                  SizedBox(height: healthDp(context, 20)),
                  _barSectionTitle(
                    context,
                    '상품 리뷰',
                    trailing: '*  필수',
                    trailingColor: const Color(0xFFEF4444),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  _reviewInputBlock(context),
                  SizedBox(height: healthDp(context, 20)),
                  _barSectionTitle(
                    context,
                    '사진 업로드',
                    trailing: '(선택)',
                    trailingColor: _kMuted,
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  _imageSection(context),
                  SizedBox(height: healthDp(context, 20)),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color(0xFFD2D2D2),
                              width: healthDp(context, 0.5),
                            ),
                            minimumSize: Size.fromHeight(healthDp(context, 40)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: healthSp(context, 16),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: healthDp(context, 20)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPink,
                            minimumSize:
                                Size.fromHeight(healthDp(context, 40)),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: healthDp(context, 18),
                                  height: healthDp(context, 18),
                                  child: CircularProgressIndicator(
                                    strokeWidth: healthDp(context, 2),
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget._isEditMode ? '수정' : '등록',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: healthSp(context, 16),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 검정 세로 막대 + 제목(font w300), `trailing` 은 라벨 바로 뒤
  Widget _barSectionTitle(
    BuildContext context,
    String title, {
    String? trailing,
    Color? trailingColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: healthDp(context, 1),
          height: healthDp(context, 16),
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(healthDp(context, 0.5)),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: healthSp(context, 16),
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
                      fontSize: healthSp(context, 12),
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

  Widget _productThumbForEdit(BuildContext context, ReviewModel r) {
    final side = healthDp(context, 80);
    final r4 = BorderRadius.circular(healthDp(context, 4));
    Widget fallback() => Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: const Color(0xFFE9E9E9),
            borderRadius: r4,
          ),
          child: Icon(
            Icons.image_outlined,
            color: _kMuted,
            size: healthDp(context, 28),
          ),
        );
    if (r.images.isNotEmpty) {
      final u = ImageUrlHelper.getReviewImageUrl(r.images.first);
      return ClipRRect(
        borderRadius: r4,
        child: Image.network(
          u,
          width: side,
          height: side,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }
    final thumb = r.productImage?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      final u = ImageUrlHelper.getImageUrl(thumb);
      return ClipRRect(
        borderRadius: r4,
        child: Image.network(
          u,
          width: side,
          height: side,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }
    return fallback();
  }

  Widget _productCard(BuildContext context, OrderItem? item, ReviewModel? edit) {
    if (item != null) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 15),
          vertical: healthDp(context, 10),
        ),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: SizedBox(
                width: healthDp(context, 80),
                height: healthDp(context, 80),
                child: (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty)
                    ? Image.network(
                        ImageUrlHelper.getImageUrl(item.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE9E9E9),
                          child: Icon(
                            Icons.image_outlined,
                            color: _kMuted,
                            size: healthDp(context, 28),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE9E9E9),
                        child: Icon(
                          Icons.image_outlined,
                          color: _kMuted,
                          size: healthDp(context, 28),
                        ),
                      ),
              ),
            ),
            SizedBox(width: healthDp(context, 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itName,
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.26,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  Text(
                    item.ctOption?.isNotEmpty == true ? item.ctOption! : '옵션 없음',
                    style: TextStyle(
                      color: const Color(0xFF898383),
                      fontSize: healthSp(context, 10),
                      fontWeight: FontWeight.w500,
                    ),
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
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 15),
          vertical: healthDp(context, 10),
        ),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _kBorder),
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
          ),
        ),
        child: Row(
          children: [
            _productThumbForEdit(context, edit),
            SizedBox(width: healthDp(context, 20)),
            Expanded(
              child: Text(
                edit.itName ?? edit.itId,
                style: TextStyle(
                  fontSize: healthSp(context, 14),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.26,
                ),
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

  Widget _scoreCard(BuildContext context) {
    final display = _score < 0.5 ? '0.0' : _score.toStringAsFixed(1);
    final r4 = Radius.circular(healthDp(context, 4));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 14),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Column(
        children: [
          Text(
            display,
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, 24),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            '받아본 상품은 어떠셨나요?',
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: healthDp(context, 2)),
                child: SizedBox(
                  width: healthDp(context, 36),
                  height: healthDp(context, 30),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _totalStarIcon(_score, i),
                        color: _totalStarColor(_score, i),
                        size: healthDp(context, 22),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _score = i + 0.5),
                              borderRadius:
                                  BorderRadius.horizontal(left: r4),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _score = i + 1.0),
                              borderRadius:
                                  BorderRadius.horizontal(right: r4),
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

  Widget _reviewInputCard(BuildContext context) {
    return Container(
      height: healthDp(context, 120),
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 12),
        vertical: healthDp(context, 10),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: TextFormField(
        controller: _reviewController,
        maxLength: 3000,
        maxLines: null,
        style: TextStyle(
          fontFamily: _kFont,
          fontSize: healthSp(context, 14),
          fontWeight: FontWeight.w300,
          color: _kInk,
        ),
        decoration: InputDecoration(
          hintText: '상품 리뷰를 작성해주세요. (최소 20자)',
          hintStyle: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 12),
            fontWeight: FontWeight.w300,
          ),
          border: InputBorder.none,
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _reviewInputBlock(BuildContext context) {
    final len = _reviewController.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewInputCard(context),
        if (_reviewBodyError != null) ...[
          SizedBox(height: healthDp(context, 8)),
          Text(
            _reviewBodyError!,
            style: TextStyle(
              color: const Color(0xFFEF4444),
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        SizedBox(height: healthDp(context, 6)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$len/3,000자',
            style: TextStyle(
              color: _kMuted,
              fontSize: healthSp(context, 10),
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageSection(BuildContext context) {
    final img = healthDp(context, 76);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: img,
                height: img,
                decoration: ShapeDecoration(
                  color: const Color(0x99D2D2D2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white,
                      size: healthDp(context, 24),
                    ),
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      '사진추가하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 10),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 5)),
            ..._imageFiles.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(right: healthDp(context, 5)),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                      child: Image.file(
                        e.value,
                        width: img,
                        height: img,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: healthDp(context, 2),
                      top: healthDp(context, 2),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _imageFiles.removeAt(e.key)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: healthDp(context, 16),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 10),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
