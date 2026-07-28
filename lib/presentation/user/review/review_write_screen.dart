import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_picker_utils.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/review_policy_footer.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

/// 리뷰 첨부 사진 슬롯 (기존 URL 또는 새로 고른 파일)
class _ReviewDraftImage {
  _ReviewDraftImage({this.file, this.serverPath});

  final XFile? file;
  final String? serverPath;

  bool get isServer =>
      serverPath != null && serverPath!.trim().isNotEmpty;
}

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

  double _score1 = 0;
  double _score2 = 0;
  double _score3 = 0;
  double _score4 = 0;
  /// 처방 리뷰 공통 상품 만족도 0=미선택, 0.5~5(0.5 단위) → `total_is_score`
  double _totalSatisfaction = 0;
  int _weightLossKg = 1;

  final _positiveController = TextEditingController();
  final _negativeController = TextEditingController();
  final _moreController = TextEditingController();

  static const int _maxImages = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final List<_ReviewDraftImage> _draftImages = [];
  bool _isLoading = false;
  bool get _isEditMode => widget.initialReview != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.initialReview;
    if (editing != null) {
      _score1 = _snapTenthRating(editing.isScore1.toDouble());
      _score2 = _snapTenthRating(editing.isScore2.toDouble());
      _score3 = _snapTenthRating(editing.isScore3.toDouble());
      _score4 = _snapTenthRating(editing.isScore4.toDouble());
      final totalRaw = (editing.totalIsScore ?? 0).toDouble();
      _totalSatisfaction =
          totalRaw > 0 ? _snapTenthRating(totalRaw) : 0.0;
      final w = editing.isOutageNum ?? 0;
      _weightLossKg = _snapWeightKg(w);
      _positiveController.text = editing.isPositiveReviewText ?? '';
      _negativeController.text = editing.isNegativeReviewText ?? '';
      _moreController.text = editing.isMoreReviewText ?? '';
      _draftImages.addAll(
        editing.images.take(_maxImages).map((p) => _ReviewDraftImage(serverPath: p)),
      );
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

  /// 주문 상품 썸네일 — 리뷰 첨부가 아닌 상품 이미지(`productImage` / `imageUrl`)
  String? _productThumbNetworkUrl({OrderItem? item, ReviewModel? review}) {
    String? guardNoImg(String? url) {
      final t = (url ?? '').toLowerCase();
      if (t.contains('no_img.png')) return null;
      return url;
    }

    final fromItem = item?.imageUrl?.trim();
    if (fromItem != null && fromItem.isNotEmpty) {
      return guardNoImg(ImageUrlHelper.getImageUrl(fromItem));
    }
    final thumb = review?.productImage?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return guardNoImg(ImageUrlHelper.getImageUrl(thumb));
    }
    return null;
  }

  Widget _productThumbWidget({OrderItem? item, ReviewModel? review}) {
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
    final url = _productThumbNetworkUrl(item: item, review: review);
    if (url == null || url.isEmpty) return fallback();
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

  void _showPhotoLimitToast() {
    AppToastOverlay.show(context, '사진은 최대 3장까지 등록 가능합니다.');
  }

  void _openPhotoSourceDropdown(BuildContext anchorContext) {
    if (_draftImages.length >= _maxImages) {
      _showPhotoLimitToast();
      return;
    }
    ImagePickerUtils.showPhotoSourceDropdown(
      context: context,
      anchorContext: anchorContext,
      onImageSelected: _applyPickedImage,
    );
  }

  Future<void> _applyPickedImage(XFile? image) async {
    if (image == null || !mounted) return;
    if (_draftImages.length >= _maxImages) {
      _showPhotoLimitToast();
      return;
    }
    try {
      final bytes = await image.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        return;
      }
      setState(() => _draftImages.add(_ReviewDraftImage(file: image)));
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
    }
  }

  Future<List<String>> _resolveImagePathsForSubmit() async {
    final paths = <String>[];
    for (final draft in _draftImages) {
      if (draft.isServer) {
        paths.add(draft.serverPath!);
        continue;
      }
      final file = draft.file;
      if (file == null) continue;
      final uploaded = await ReviewService.uploadReviewImage(file);
      if (uploaded != null && uploaded.isNotEmpty) {
        paths.add(uploaded);
      }
    }
    return paths.take(_maxImages).toList();
  }

  Widget _draftImageThumb(_ReviewDraftImage draft, double size) {
    if (draft.isServer) {
      final url = ImageUrlHelper.getReviewImageUrl(draft.serverPath);
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _draftImagePlaceholder(size),
      );
    }

    final file = draft.file!;
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _draftImagePlaceholder(size);
        }
        return Image.memory(
          snapshot.data!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _draftImagePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0x4CD2D2D2),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: size * 0.3, color: _kMuted),
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
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: healthSp(context, 14),
                fontWeight: FontWeight.w500,
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(
                        top: healthDp(context, 10),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 27),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                hint:
                                    '직접 사용(복용)해보며 느낀 점과 만족스러웠던 점 어떤 분들께 추천하고 싶은지 함께 작성해주세요. (최소 20자)',
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              _buildReviewTextSection(
                                barTitle: '상품 리뷰 아쉬운 점',
                                requiredField: true,
                                controller: _negativeController,
                                hint:
                                    '사용(복용)하면서 아쉬웠던 점과 개선되었으면 하는 부분이 있다면 알려주세요. (최소 20자)',
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              _buildReviewTextSection(
                                barTitle: '상품 리뷰 꿀팁',
                                requiredField: false,
                                controller: _moreController,
                                hint:
                                    '사용(복용)하시면서 알게 된 꿀팁이나 효과적으로 활용하는 방법이 있다면 공유해주세요. (최소 20자)',
                              ),
                              SizedBox(height: healthDp(context, 20)),
                              _buildImageSection(),
                              SizedBox(height: healthDp(context, 20)),
                            ],
                          ),
                        ),
                        const ReviewPolicyFooter(),
                      ],
                    ),
                  ),
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
          SizedBox(height: healthDp(context, 5)),
          _barSectionTitle('주문상품 정보'),
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
                _productThumbWidget(item: firstItem),
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
                          fontWeight: FontWeight.w700,
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
        SizedBox(height: healthDp(context, 5)),
        _barSectionTitle('주문상품 정보'),
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
              _productThumbWidget(review: review),
              SizedBox(width: healthDp(context, 20)),
              Expanded(
                child: Text(
                  review.itName ?? review.itId,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: healthSp(context, 14),
                    fontWeight: FontWeight.w700,
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

  Color _weightScaleLabelColor(int markerKg) {
    return markerKg <= _weightLossKg ? _kPink : const Color(0xFFA19E9E);
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
                color: const Color(0xFF1A1A1E),
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
        SizedBox(height: healthDp(context, 20)),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final trackH = healthDp(context, 8);
            final thumbR = healthDp(context, 7);
            final labelW = healthDp(context, 36);

            double xForKg(int kg) =>
                w <= 0 ? 0 : ((kg - 1) / 29.0) * w;

            void setFromLocalDx(double dx) {
              if (w <= 0) return;
              final t = (dx / w).clamp(0.0, 1.0);
              final kg = (1 + t * 29).round().clamp(1, 30);
              setState(() => _weightLossKg = kg);
            }

            return Column(
              children: [
                SizedBox(
                  height: thumbR * 2,
                  width: w,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => setFromLocalDx(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) =>
                        setFromLocalDx(d.localPosition.dx),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 트랙(비활성)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: thumbR - trackH / 2,
                          child: Container(
                            height: trackH,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F6F6),
                              borderRadius: BorderRadius.circular(trackH / 2),
                            ),
                          ),
                        ),
                        // 트랙(활성)
                        Positioned(
                          left: 0,
                          width: xForKg(_weightLossKg)
                              .clamp(0.0, w)
                              .toDouble(),
                          top: thumbR - trackH / 2,
                          child: Container(
                            height: trackH,
                            decoration: BoxDecoration(
                              color: _kPink,
                              borderRadius: BorderRadius.circular(trackH / 2),
                            ),
                          ),
                        ),
                        // 썸(핑크 원)
                        Positioned(
                          left: xForKg(_weightLossKg) - thumbR,
                          top: 0,
                          child: Container(
                            width: thumbR * 2,
                            height: thumbR * 2,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: healthDp(context, 4)),
                SizedBox(
                  width: w,
                  height: healthSp(context, 12) * 1.3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final kg in _weightLabelMarks)
                        Positioned(
                          left: kg == 1
                              ? 0
                              : kg == 30
                                  ? (w - labelW).clamp(0.0, w)
                                  : (xForKg(kg) - labelW / 2).clamp(
                                      0.0,
                                      (w - labelW).clamp(0.0, w),
                                    ),
                          width: labelW,
                          child: Text(
                            '${kg}kg',
                            textAlign: kg == 1
                                ? TextAlign.left
                                : kg == 30
                                    ? TextAlign.right
                                    : TextAlign.center,
                            style: TextStyle(
                              fontFamily: _kFont,
                              color: _weightScaleLabelColor(kg),
                              fontSize: healthSp(context, 10),
                              fontWeight: FontWeight.w300,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
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
          trailing: '*필수',
          trailingColor: const Color(0xFFEF4444),
        ),
        SizedBox(height: healthDp(context, 10)),
        _buildTotalSatisfactionSummaryCard(),
        SizedBox(height: healthDp(context, 10)),
        _scoreRow('효과', _score1, (v) => setState(() => _score1 = v)),
        SizedBox(height: healthDp(context, 10)),
        _scoreRow('가성비', _score2, (v) => setState(() => _score2 = v)),
        SizedBox(height: healthDp(context, 10)),
        _scoreRow('향/맛', _score3, (v) => setState(() => _score3 = v)),
        SizedBox(height: healthDp(context, 10)),
        _scoreRow('편리함', _score4, (v) => setState(() => _score4 = v)),
      ],
    );
  }

  /// 감량 kg 눈금 라벨 (선택은 1~30 1kg 단위)
  static const List<int> _weightLabelMarks = [1, 5, 10, 15, 20, 25, 30];

  /// 효과~편리함 / 상품 만족도 — 0.1 단위 (4.8, 4.2 등)
  double _snapTenthRating(double raw) => appStarSnapTenth(raw);

  /// 감량 kg — 1~30, 1kg 단위
  int _snapWeightKg(int raw) {
    if (raw < 1) return 1;
    if (raw > 30) return 30;
    return raw;
  }

  String _formatTenthRatingDisplay(double rating) {
    if (rating < 0.05) return '0.0';
    final v = _snapTenthRating(rating);
    if ((v * 10).round() % 10 == 0) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(1);
  }

  /// 공통 상품 만족도(별) — `total_is_score` 저장
  Widget _buildTotalSatisfactionSummaryCard() {
    final display = _formatTenthRatingDisplay(_totalSatisfaction);
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
              fontSize: healthSp(context, 20),
              fontFamily: _kFont,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppInteractiveStarRating(
            rating: _totalSatisfaction,
            onRatingChanged: (v) => setState(() => _totalSatisfaction = v),
            starSize: healthDp(context, 24),
            gap: healthDp(context, 4),
            color: _kPink,
            alignment: MainAxisAlignment.center,
            snapMode: AppStarSnapMode.tenth,
          ),
        ],
      ),
    );
  }
  static const double _scoreLabelWidthBase = 56;

  Widget _scoreRow(String label, double score, ValueChanged<double> onChanged) {
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
      // 상품 만족도 별과 동일하게 가운데 정렬 → 시작 위치 맞춤
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: healthDp(context, _scoreLabelWidthBase),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: healthSp(context, 12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          AppInteractiveStarRating(
            rating: score,
            onRatingChanged: onChanged,
            starSize: healthDp(context, 24),
            gap: healthDp(context, 4),
            color: _kPink,
            alignment: MainAxisAlignment.center,
            snapMode: AppStarSnapMode.tenth,
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
            horizontal: healthDp(context, 20),
            vertical: healthDp(context, 20),
          ),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _kBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 7)),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: TextFormField(
                controller: controller,
                maxLength: 3000,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: healthSp(context, 12),
                  fontWeight: FontWeight.w500,
                  color: _kInk,
                  letterSpacing: -0.6,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontFamily: _kFont,
                    color: _kMuted,
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.only(
                    bottom: healthDp(context, 14),
                  ),
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
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  '${controller.text.length}/3,000자',
                  style: TextStyle(
                    fontFamily: _kFont,
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
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
        Builder(
          builder: (context) {
            final thumb = healthDp(context, 76);
            return SizedBox(
              height: thumb,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Builder(
                      builder: (anchorContext) {
                        return InkWell(
                          onTap: () => _openPhotoSourceDropdown(anchorContext),
                          child: Container(
                            width: thumb,
                            height: thumb,
                            decoration: ShapeDecoration(
                              color: const Color(0x99D2D2D2),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(healthDp(context, 10)),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  AppAssets.addPhotoIcon,
                                  width: healthDp(context, 34),
                                  height: healthDp(context, 31),
                                ),
                                SizedBox(height: healthDp(context, 4)),
                                Text(
                                  '사진추가하기',
                                  style: TextStyle(
                                    fontFamily: _kFont,
                                    color: Colors.white,
                                    fontSize: healthSp(context, 10),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_draftImages.isNotEmpty)
                      SizedBox(width: healthDp(context, 5)),
                    ..._draftImages.asMap().entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.only(right: healthDp(context, 5)),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  healthDp(context, 10)),
                              child: _draftImageThumb(e.value, thumb),
                            ),
                            Positioned(
                              right: healthDp(context, 2),
                              top: healthDp(context, 2),
                              child: InkWell(
                                onTap: () => setState(
                                    () => _draftImages.removeAt(e.key)),
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
              ),
            );
          },
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
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 27),
          healthDp(context, 10),
          healthDp(context, 27),
          healthDp(context, 10),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE9E9E9),
              width: healthDp(context, 0.5),
            ),
          ),
        ),
        child: Row(
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 리뷰 제출
  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      AppToastOverlay.show(context, '필수 항목을 작성해주세요.');
      return;
    }

    if (_totalSatisfaction < 0.1 ||
        _score1 < 0.1 ||
        _score2 < 0.1 ||
        _score3 < 0.1 ||
        _score4 < 0.1) {
      AppToastOverlay.show(context, '필수 별점을 작성해주세요.');
      return;
    }

    if (_positiveController.text.trim().length < 20 ||
        _negativeController.text.trim().length < 20) {
      AppToastOverlay.show(context, '필수 리뷰 내용을 작성해주세요. (최소 20자)');
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

      final imagePaths = await _resolveImagePathsForSubmit();
      if (imagePaths.length != _draftImages.length) {
        return;
      }

      // 작성/수정 공용 리뷰 모델 생성
      final totalSat = _snapTenthRating(_totalSatisfaction);
      final review = ReviewModel(
        isId: editTarget?.isId,
        mbId: user.id,
        odId: editTarget?.odId ?? widget.orderDetail?.odId,
        itId: itId,
        isName: user.name,
        isScore1: _snapTenthRating(_score1),
        isScore2: _snapTenthRating(_score2),
        isScore3: _snapTenthRating(_score3),
        isScore4: _snapTenthRating(_score4),
        totalIsScore: totalSat,
        isRvkind: editTarget?.isRvkind ?? 'prescription',
        isRecommend: editTarget?.isRecommend ?? 'y',
        isPositiveReviewText: _positiveController.text,
        isNegativeReviewText: _negativeController.text.isNotEmpty 
            ? _negativeController.text 
            : null,
        // 선택 항목 — 빈 문자열로 보내야 수정 시 DB 값을 지울 수 있음
        isMoreReviewText: _moreController.text.trim(),
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

