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
  /// 처방 리뷰 공통 상품 만족도 0=미선택, 0.5~5(0.5 단위) → `total_is_score`
  double _totalSatisfaction = 0;
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
      _totalSatisfaction = _snapTotalRating((editing.totalIsScore ?? 0).toDouble());
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
    _totalSatisfaction = 0.0;
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
    final side = healthDp(context, 80);
    final r4 = BorderRadius.circular(healthDp(context, 4));
    Widget fallback() => Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: r4,
          ),
          child: Icon(Icons.image_outlined,
              color: _kMuted, size: healthDp(context, 28)),
        );
    return ClipRRect(
      borderRadius: r4,
      child: Image.network(
        url,
        width: side,
        height: side,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  Widget _editReviewProductThumb(ReviewModel review) {
    final side = healthDp(context, 80);
    final r4 = BorderRadius.circular(healthDp(context, 4));
    Widget fallback() => Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAEA),
            borderRadius: r4,
          ),
          child: Icon(Icons.image_outlined,
              color: _kMuted, size: healthDp(context, 28)),
        );
    if (review.images.isEmpty) return fallback();
    final u = ImageUrlHelper.getReviewImageUrl(review.images.first);
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

  /// 섹션 제목 앞 세로 막대(| 느낌, 두께 2) — 막대는 검정, `trailing` 은 라벨 바로 뒤에 붙임
  Widget _barSectionTitle(
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

  @override
  Widget build(BuildContext context) {
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
              title: _isEditMode ? '리뷰수정' : '리뷰쓰기',
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
              if (!_isEditMode)
                _buildProductSection()
              else
                _buildReviewProductSectionForEdit(),
              SizedBox(height: healthDp(context, 20)),
              _buildWeightSection(),
              SizedBox(height: healthDp(context, 20)),
              _buildSatisfactionSection(),
              SizedBox(height: healthDp(context, 20)),
              _buildReviewTextSection(
                barTitle: '상품 리뷰 좋았던 점',
                requiredField: true,
                controller: _positiveController,
                hint: '직접 사용(복용)해보며 느낀 점과 만족스러웠던 점 어떤 분들께 추천하고 싶은지 함께 작성해주세요. (최소 20자)',
              ),
              SizedBox(height: healthDp(context, 20)),
              _buildReviewTextSection(
                barTitle: '상품 리뷰 아쉬운 점',
                requiredField: true,
                controller: _negativeController,
                hint: '사용(복용)하면서 아쉬웠던 점과 개선되었으면 하는 부분이 있다면 알려주세요. (최소 20자)',
              ),
              SizedBox(height: healthDp(context, 20)),
              _buildReviewTextSection(
                barTitle: '상품 리뷰 꿀팁',
                requiredField: false,
                controller: _moreController,
                hint: '사용(복용)하시면서 알게 된 꿀팁이나 효과적으로 활용하는 방법이 있다면 공유해주세요. (최소 20자)',
              ),
              SizedBox(height: healthDp(context, 20)),
              _buildImageSection(),
              SizedBox(height: healthDp(context, 20)),
              _buildBottomButtons(),
                ],
              ),
            ),
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
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
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
                _orderProductThumb(firstItem.imageUrl),
                SizedBox(width: healthDp(context, 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.itName,
                        style: TextStyle(
                          fontFamily: _kFont,
                          fontSize: healthSp(context, 14),
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.26,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 10)),
                      Text(
                        '수량: ${firstItem.ctQty}${firstItem.ctOption != null && firstItem.ctOption!.isNotEmpty ? ' / ${firstItem.ctOption}' : ''}',
                        style: TextStyle(
                          fontFamily: _kFont,
                          color: const Color(0xFF898383),
                          fontSize: healthSp(context, 10),
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
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
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
              _editReviewProductThumb(review),
              SizedBox(width: healthDp(context, 20)),
              Expanded(
                child: Text(
                  review.itName ?? review.itId,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: healthSp(context, 14),
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
        SizedBox(height: healthDp(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '얼마나 감량하셨나요?',
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w300,
                letterSpacing: -1.32,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 10),
                    vertical: healthDp(context, 4),
                  ),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, 0.5),
                        color: const Color(0xFFD2D2D2),
                      ),
                      borderRadius: BorderRadius.circular(healthDp(context, 5)),
                    ),
                  ),
                  child: Text(
                    '$_weightLossKg',
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: healthSp(context, 10),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  'kg',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _kPink,
            inactiveTrackColor: const Color(0xFFF6F6F6),
            trackHeight: healthDp(context, 8),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: healthDp(context, 6),
            ),
            trackShape: const RoundedRectSliderTrackShape(),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: healthDp(context, 14),
            ),
          ),
          child: Slider(
            value: _weightLossKg.clamp(1, 50).toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (v) => setState(() => _weightLossKg = v.round().clamp(1, 50)),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: const Color(0xFFA19E9E),
                fontSize: healthSp(context, 10),
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '10kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: const Color(0xFFA19E9E),
                fontSize: healthSp(context, 10),
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '20kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: healthSp(context, 10),
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '30kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: healthSp(context, 10),
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '40kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: healthSp(context, 10),
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              '50kg',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: healthSp(context, 10),
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
        SizedBox(height: healthDp(context, 10)),
        _buildTotalSatisfactionSummaryCard(),
        SizedBox(height: healthDp(context, 16)),
        _scoreRow('효과', _score1, (v) => setState(() => _score1 = v)),
        SizedBox(height: healthDp(context, 8)),
        _scoreRow('가성비', _score2, (v) => setState(() => _score2 = v)),
        SizedBox(height: healthDp(context, 8)),
        _scoreRow('향/맛', _score3, (v) => setState(() => _score3 = v)),
        SizedBox(height: healthDp(context, 8)),
        _scoreRow('편리함', _score4, (v) => setState(() => _score4 = v)),
      ],
    );
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

  /// 공통 상품 만족도(별) — `total_is_score` 저장, 가로폭은 `_scoreRow` 와 동일(전체 너비)
  Widget _buildTotalSatisfactionSummaryCard() {
    final display =
        _totalSatisfaction < 0.5 ? '0.0' : _totalSatisfaction.toStringAsFixed(1);
    final r4 = Radius.circular(healthDp(context, 4));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, 24),
              fontFamily: _kFont,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: healthDp(context, 6)),
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
                        _totalStarIcon(_totalSatisfaction, i),
                        color: _totalStarColor(_totalSatisfaction, i),
                        size: healthDp(context, 24),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _totalSatisfaction = i + 0.5),
                              borderRadius:
                                  BorderRadius.horizontal(left: r4),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _totalSatisfaction = i + 1.0),
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

  Widget _scoreRow(String label, int score, ValueChanged<int> onChanged) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 45),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: healthDp(context, 42),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w500,
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
                    size: healthDp(context, 20),
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
        SizedBox(height: healthDp(context, 10)),
        Container(
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
            controller: controller,
            maxLength: 3000,
            maxLines: null,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, 14),
              fontWeight: FontWeight.w300,
              color: _kInk,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: _kFont,
                color: _kMuted,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.zero,
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
        SizedBox(height: healthDp(context, 6)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${controller.text.length}/3,000자',
            style: TextStyle(
              fontFamily: _kFont,
              color: _kMuted,
              fontSize: healthSp(context, 10),
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
        SizedBox(height: healthDp(context, 10)),
        Row(
          children: [
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: healthDp(context, 76),
                height: healthDp(context, 76),
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
                        fontFamily: _kFont,
                        color: Colors.white,
                        fontSize: healthSp(context, 10),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 5)),
            ..._imageFiles.asMap().entries.map((e) {
              final img = healthDp(context, 76);
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
                            color: Colors.white,
                            size: healthDp(context, 16),
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
            fontFamily: _kFont,
            color: _kMuted,
            fontSize: healthSp(context, 10),
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
            height: healthDp(context, 40),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: healthDp(context, 0.5),
                  color: const Color(0xFFD2D2D2),
                ),
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
              ),
            ),
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: _kFont,
                  color: _kMuted,
                  fontSize: healthSp(context, 16),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 20)),
        Expanded(
          child: Container(
            height: healthDp(context, 40),
            decoration: ShapeDecoration(
              color: _kPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
              ),
            ),
            child: TextButton(
              onPressed: _isLoading ? null : _submitReview,
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
                      _isEditMode ? '수정' : '등록',
                      style: TextStyle(
                        fontFamily: _kFont,
                        color: Colors.white,
                        fontSize: healthSp(context, 16),
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
        return;
      }
      
      final currentOrderFirstItem = widget.orderDetail != null && widget.orderDetail!.products.isNotEmpty
          ? widget.orderDetail!.products.first
          : null;
      final editTarget = widget.initialReview;
      final itId = editTarget?.itId ?? currentOrderFirstItem?.itId;
      if (itId == null || itId.isEmpty) {
        return;
      }

      // 이미지 경로 리스트
      List<String> imagePaths = _imageFiles.map((file) => file.path).toList();
      
      if (_positiveController.text.trim().length < 20 ||
          _negativeController.text.trim().length < 20) {
        return;
      }

      if (_totalSatisfaction < 0.5) {
        return;
      }

      // 작성/수정 공용 리뷰 모델 생성
      final totalSat = _snapTotalRating(_totalSatisfaction);
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
        totalIsScore: totalSat,
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
          Navigator.pop(context, true);
        }
      }
    } catch (_) {
      // 스낵바 없이 조용히 실패 처리
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

