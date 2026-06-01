import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

/// 리뷰 작성 화면용 사진 슬롯 (기존 URL 또는 새로 고른 파일)
class _ReviewDraftImage {
  _ReviewDraftImage({this.file, this.serverPath});

  final XFile? file;
  final String? serverPath;

  bool get isServer =>
      serverPath != null && serverPath!.trim().isNotEmpty;
}

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
  /// 0 = 만족도 미선택, 0.1~5(0.1 단위) = `total_is_score`
  double _score = 0;
  bool _isLoading = false;
  /// 카드 밖에 표시 (입력란 안에는 검증 문구 없음)
  String? _reviewBodyError;
  static const int _maxImages = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final List<_ReviewDraftImage> _draftImages = [];
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
      _score = _snapTenthRating((r.totalIsScore ?? 0).toDouble());
      _draftImages.addAll(
        r.images.take(_maxImages).map((p) => _ReviewDraftImage(serverPath: p)),
      );
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
    if (_draftImages.length >= _maxImages) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      return;
    }

    setState(() => _draftImages.add(_ReviewDraftImage(file: image)));
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

  Widget _draftImageThumb(BuildContext context, _ReviewDraftImage draft, double size) {
    if (draft.isServer) {
      final url = ImageUrlHelper.getReviewImageUrl(draft.serverPath);
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(size),
      );
    }

    final file = draft.file!;
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _imagePlaceholder(size);
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

  Widget _imagePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0x4CD2D2D2),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: size * 0.3, color: _kMuted),
    );
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

    if (_score < 0.1) {
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

      final paths = await _resolveImagePathsForSubmit();
      if (paths.length != _draftImages.length) {
        return;
      }

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
        totalIsScore: _snapTenthRating(_score),
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
                  SizedBox(height: healthDp(context, 20)),
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

  /// 상품 만족도 — 0.1 단위 (4.8, 4.2 등)
  double _snapTenthRating(double raw) {
    if (raw <= 0) return 0.0;
    final c = raw.clamp(0.1, 5.0);
    return (c * 10).round() / 10.0;
  }

  Widget _fractionalStar(BuildContext context, double fill, double size) {
    final f = fill.clamp(0.0, 1.0);
    if (f <= 0) {
      return Icon(Icons.star_border_rounded, color: _kPink, size: size);
    }
    if (f >= 1 - 1e-9) {
      return Icon(Icons.star_rounded, color: _kPink, size: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.star_border_rounded, color: _kPink, size: size),
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRect(
              child: SizedBox(
                width: size * f,
                height: size,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: size,
                  maxWidth: size,
                  minHeight: size,
                  maxHeight: size,
                  child: Icon(Icons.star_rounded, color: _kPink, size: size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactiveStarRow(
    BuildContext context, {
    required double rating,
    required ValueChanged<double> onRatingChanged,
    MainAxisAlignment alignment = MainAxisAlignment.center,
  }) {
    const starSize = 24.0;
    const gap = 4.0;
    final starDp = healthDp(context, starSize);
    final gapDp = healthDp(context, gap);
    final rowWidth = starDp * 5 + gapDp * 4;

    void applyLocalDx(double dx) {
      final t = (dx / rowWidth).clamp(0.0, 1.0);
      final raw = t * 5.0;
      if (raw <= 0) {
        onRatingChanged(0);
        return;
      }
      onRatingChanged(_snapTenthRating(raw));
    }

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gapDp,
      children: List.generate(
        5,
        (i) => _fractionalStar(context, rating - i, starDp),
      ),
    );

    final interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => applyLocalDx(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => applyLocalDx(d.localPosition.dx),
      child: SizedBox(width: rowWidth, child: stars),
    );

    if (alignment == MainAxisAlignment.center) {
      return Center(child: interactive);
    }
    return interactive;
  }

  Widget _scoreCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 10),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '받아본 상품은 어떠셨나요?',
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          _interactiveStarRow(
            context,
            rating: _score,
            onRatingChanged: (v) => setState(() => _score = v),
          ),
        ],
      ),
    );
  }

  Widget _reviewInputBlock(BuildContext context) {
    final len = _reviewController.text.length;
    return Container(
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
              controller: _reviewController,
              maxLength: 3000,
              maxLines: null,
              expands: true,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w500,
                color: _kInk,
                letterSpacing: -0.6,
              ),
              decoration: InputDecoration(
                hintText: '상품 리뷰를 작성해주세요. (최소 20자)',
                hintStyle: TextStyle(
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
            ),
          ),
          if (_reviewBodyError != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  _reviewBodyError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFEF4444),
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              '$len/3,000자',
              style: TextStyle(
                color: _kMuted,
                fontSize: healthSp(context, 10),
                fontWeight: FontWeight.w300,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageSection(BuildContext context) {
    final img = healthDp(context, 76);
    final canAddMore = _draftImages.length < _maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canAddMore)
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
                      SvgPicture.asset(
                        AppAssets.reviewAddPhotoIcon,
                        width: healthDp(context, 34),
                        height: healthDp(context, 31),
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
            if (canAddMore && _draftImages.isNotEmpty)
              SizedBox(width: healthDp(context, 5)),
            ..._draftImages.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(right: healthDp(context, 5)),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                      child: _draftImageThumb(context, e.value, img),
                    ),
                    Positioned(
                      right: healthDp(context, 2),
                      top: healthDp(context, 2),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _draftImages.removeAt(e.key)),
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
