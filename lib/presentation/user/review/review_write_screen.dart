import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/navigation/app_action_gate.dart';
import '../../../core/utils/image_picker_utils.dart';
import '../../../core/utils/web_horizontal_nav_lock.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
import 'review_write_finish.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/review_photo_add_card.dart';
import '../../common/widgets/review_policy_footer.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../health/health_common/widgets/health_focus_outline_box.dart';

/// 리뷰 첨부 사진 슬롯 (기존 URL 또는 새로 고른 파일)
class _ReviewDraftImage {
  _ReviewDraftImage({this.file, this.serverPath, this.previewBytes});

  final XFile? file;
  final String? serverPath;
  final Uint8List? previewBytes;

  bool get isServer => serverPath != null && serverPath!.trim().isNotEmpty;
}

class _PrescriptionReviewDraft {
  double score1 = 0;
  double score2 = 0;
  double score3 = 0;
  double score4 = 0;
  int weightLossKg = 1;
  String positive = '';
  String negative = '';
  String more = '';
  List<_ReviewDraftImage> images = [];
}

/// 리뷰 작성 화면
class ReviewWriteScreen extends StatefulWidget {
  final OrderDetailModel? orderDetail;
  final ReviewModel? initialReview;

  /// 선택 화면에서 넘어온 작성 대상 상품 (없으면 주문 본품 전체 중 첫 상품)
  final List<OrderItem>? selectedProducts;

  const ReviewWriteScreen({
    super.key,
    this.orderDetail,
    this.initialReview,
    this.selectedProducts,
  });

  const ReviewWriteScreen.edit({
    super.key,
    required ReviewModel review,
  })  : orderDetail = null,
        initialReview = review,
        selectedProducts = null;

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final _formKey = GlobalKey<FormState>();

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const String _kFont = 'Gmarket Sans TTF';

  double _score1 = 0;
  double _score2 = 0;
  double _score3 = 0;
  double _score4 = 0;
  int _weightLossKg = 1;
  final _weightController = TextEditingController(text: '1');
  final _weightFocus = FocusNode();

  final _positiveController = TextEditingController();
  final _negativeController = TextEditingController();
  final _moreController = TextEditingController();

  static const int _maxImages = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final List<_ReviewDraftImage> _draftImages = [];
  bool _isLoading = false;
  bool get _isEditMode => widget.initialReview != null;

  int _productIndex = 0;
  final Map<int, _PrescriptionReviewDraft> _drafts = {};

  List<OrderItem> get _targetProducts {
    final selected = widget.selectedProducts;
    if (selected != null && selected.isNotEmpty) return selected;
    final od = widget.orderDetail;
    if (od == null || od.products.isEmpty) return const [];
    return od.products.where((p) {
      if (p.itId.trim().isEmpty) return false;
      final parent = (p.parent ?? '').trim();
      if (parent.isNotEmpty) return false;
      final kind = (p.ctKind ?? '').toLowerCase().trim();
      if (kind.startsWith('supply_add|')) return false;
      return true;
    }).toList();
  }

  bool get _isMulti => !_isEditMode && _targetProducts.length > 1;

  OrderItem? get _currentProduct {
    final list = _targetProducts;
    if (list.isEmpty) return null;
    final i = _productIndex.clamp(0, list.length - 1);
    return list[i];
  }

  @override
  void initState() {
    super.initState();
    setBlockBrowserBackSwipe(true);
    _weightFocus.addListener(() {
      if (!_weightFocus.hasFocus && mounted) {
        _commitWeightText(allowBelow: true);
      }
    });
    final editing = widget.initialReview;
    if (editing != null) {
      _score1 = _snapTenthRating(editing.isScore1.toDouble());
      _score2 = _snapTenthRating(editing.isScore2.toDouble());
      _score3 = _snapTenthRating(editing.isScore3.toDouble());
      _score4 = _snapTenthRating(editing.isScore4.toDouble());
      final w = editing.isOutageNum ?? 0;
      _weightLossKg = _snapWeightKg(w);
      _syncWeightField();
      _positiveController.text = editing.isPositiveReviewText ?? '';
      _negativeController.text = editing.isNegativeReviewText ?? '';
      _moreController.text = editing.isMoreReviewText ?? '';
      _draftImages.addAll(
        editing.images
            .take(_maxImages)
            .map((p) => _ReviewDraftImage(serverPath: p)),
      );
      return;
    }

    final od = widget.orderDetail;
    if (od == null) {
      return;
    }
    _weightLossKg = 1;
    _syncWeightField();
  }

  @override
  void dispose() {
    setBlockBrowserBackSwipe(false);
    _weightController.dispose();
    _weightFocus.dispose();
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
    if (thumb != null &&
        thumb.isNotEmpty &&
        !ImageUrlHelper.isReviewAttachmentUrl(thumb)) {
      final normalized =
          ImageUrlHelper.normalizeThumbnailUrl(thumb, review?.itId) ?? thumb;
      if (ImageUrlHelper.isReviewAttachmentUrl(normalized)) return null;
      return guardNoImg(ImageUrlHelper.getImageUrl(normalized));
    }
    return null;
  }

  Widget _productThumbWidget({OrderItem? item, ReviewModel? review}) {
    final side = healthDp(context, 64);
    final r4 = BorderRadius.circular(healthDp(context, 8));
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
    AppToastOverlay.showAlert(context, '사진은 최대 3장까지 등록할 수 있습니다.');
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
        if (mounted) {
          AppToastOverlay.show(context, '사진은 파일당 5MB 이하만 등록할 수 있습니다.');
        }
        return;
      }
      setState(
        () => _draftImages.add(
          _ReviewDraftImage(file: image, previewBytes: bytes),
        ),
      );
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
    }
  }

  Future<List<String>> _resolveImagePathsForSubmit() async {
    final uploads = <Future<String?>>[];
    for (final draft in _draftImages) {
      if (draft.isServer) {
        uploads.add(Future.value(draft.serverPath!.trim()));
        continue;
      }
      final file = draft.file;
      if (file == null) {
        uploads.add(Future.value(null));
        continue;
      }
      uploads.add(ReviewService.uploadReviewImage(file));
    }
    final results = await Future.wait(uploads);
    return results
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .take(_maxImages)
        .toList();
  }

  Widget _draftImageThumb(_ReviewDraftImage draft, double size) {
    if (draft.isServer) {
      final url = ImageUrlHelper.getImageUrl(draft.serverPath);
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _draftImagePlaceholder(size),
      );
    }

    final file = draft.file!;
    if (draft.previewBytes != null && draft.previewBytes!.isNotEmpty) {
      return Image.memory(
        draft.previewBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
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
    double trailingFontBase = 12,
    double gapBase = 10,
    double trailingGapBase = 5,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: healthDp(context, 2),
          height: healthDp(context, 14),
          decoration: BoxDecoration(
            color: _kInk,
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        SizedBox(width: healthDp(context, gapBase)),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, 14),
              fontWeight: FontWeight.w500,
              letterSpacing: -1.26,
              color: _kInk,
            ),
          ),
        ),
        if (trailing != null && trailing.isNotEmpty) ...[
          SizedBox(width: healthDp(context, trailingGapBase)),
          Text(
            trailing,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, trailingFontBase),
              fontWeight: FontWeight.w300,
              color: trailingColor ?? _kMuted,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: _kFont),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: _kFont),
    );
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

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
              leadingIconSize: healthDp(context, 16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!_isEditMode && _isMulti)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        healthDp(context, 20),
                        healthDp(context, 10),
                        healthDp(context, 20),
                        0,
                      ),
                      child: _buildProductTabs(),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_isEditMode)
                                _buildProductSection()
                              else
                                _buildReviewProductSectionForEdit(),
                              SizedBox(height: healthDp(context, 24)),
                              _buildWeightSection(),
                              SizedBox(height: healthDp(context, 24)),
                              _buildSatisfactionSection(),
                              SizedBox(height: healthDp(context, 24)),
                              _buildReviewTextSection(
                                barTitle: '상품 리뷰 좋았던 점',
                                requiredField: true,
                                controller: _positiveController,
                                hint:
                                    '직접 사용(복용)해보며 느낀 점과 만족스러웠던 점 어떤 분들께 추천하고 싶은지 함께 작성해주세요. (최소 20자)',
                              ),
                              SizedBox(height: healthDp(context, 24)),
                              _buildReviewTextSection(
                                barTitle: '상품 리뷰 아쉬운 점',
                                requiredField: true,
                                controller: _negativeController,
                                hint:
                                    '사용(복용)하면서 아쉬웠던 점과 개선되었으면 하는 부분이 있다면 알려주세요. (최소 20자)',
                              ),
                              SizedBox(height: healthDp(context, 24)),
                              _buildReviewTextSection(
                                barTitle: '상품 리뷰 꿀팁',
                                requiredField: false,
                                isLast: true,
                                controller: _moreController,
                                hint:
                                    '사용(복용)하시면서 알게 된 꿀팁이나 효과적으로 활용하는 방법이 있다면 공유해주세요.',
                              ),
                              SizedBox(height: healthDp(context, 24)),
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

  Widget _buildProductTabs() {
    final list = _targetProducts;
    return SizedBox(
      height: healthDp(context, 25),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => SizedBox(width: healthDp(context, 8)),
        itemBuilder: (_, i) => _buildProductStepChip(i),
      ),
    );
  }

  /// 0=완료(이미 지나감), 1=작성중(현재), 2=대기(아직 안 씀)
  int _productStepKind(int index) {
    if (index < _productIndex) return 0;
    if (index == _productIndex) return 1;
    return 2;
  }

  bool _isProductDraftComplete(int index) {
    if (index == _productIndex) return _canProceedCurrent;
    final d = _drafts[index];
    if (d == null) return false;
    return d.score1 >= 0.1 &&
        d.score2 >= 0.1 &&
        d.score3 >= 0.1 &&
        d.score4 >= 0.1 &&
        d.positive.trim().length >= 20 &&
        d.negative.trim().length >= 20;
  }

  Widget _buildProductStepChip(int index) {
    final kind = _productStepKind(index);
    final label = '${index + 1}번 상품';
    final showIcon = kind != 2;

    late final Color bg;
    late final Color border;
    late final Color textColor;
    List<BoxShadow>? shadows;

    switch (kind) {
      case 0: // 완료
        bg = const Color(0xFFFFF0F5);
        border = const Color(0xFFFFC5D8);
        textColor = _kPink;
        shadows = null;
        break;
      case 1: // 작성중
        bg = _kPink;
        border = _kPink;
        textColor = Colors.white;
        shadows = [
          BoxShadow(
            color: const Color(0x2DFF5A8D),
            blurRadius: healthDp(context, 12),
            offset: Offset(0, healthDp(context, 5)),
          ),
        ];
        break;
      default: // 대기
        bg = Colors.white;
        border = const Color(0xFFD8D5D5);
        textColor = _kMuted;
        shadows = null;
        break;
    }

    return GestureDetector(
      onTap: () => _goToProductIndex(index),
      child: Container(
        height: healthDp(context, 25),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
        decoration: ShapeDecoration(
          color: bg,
          shadows: shadows,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: border),
            borderRadius: BorderRadius.circular(healthDp(context, 999)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                Icons.check_circle,
                size: healthDp(context, 9),
                color: textColor,
              ),
              SizedBox(width: healthDp(context, 4)),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: healthSp(context, 10),
                fontFamily: _kFont,
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: healthSp(context, -0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCurrentDraft() {
    _drafts[_productIndex] = _PrescriptionReviewDraft()
      ..score1 = _score1
      ..score2 = _score2
      ..score3 = _score3
      ..score4 = _score4
      ..weightLossKg = _weightLossKg
      ..positive = _positiveController.text
      ..negative = _negativeController.text
      ..more = _moreController.text
      ..images = List<_ReviewDraftImage>.from(_draftImages);
  }

  void _loadDraft(int index) {
    final d = _drafts[index];
    if (d == null) {
      _score1 = 0;
      _score2 = 0;
      _score3 = 0;
      _score4 = 0;
      _weightLossKg = 1;
      _syncWeightField();
      _positiveController.clear();
      _negativeController.clear();
      _moreController.clear();
      _draftImages.clear();
      return;
    }
    _score1 = d.score1;
    _score2 = d.score2;
    _score3 = d.score3;
    _score4 = d.score4;
    _weightLossKg = d.weightLossKg;
    _syncWeightField();
    _positiveController.text = d.positive;
    _negativeController.text = d.negative;
    _moreController.text = d.more;
    _draftImages
      ..clear()
      ..addAll(d.images);
  }

  void _goToProductIndex(int index) {
    if (index == _productIndex) return;

    // 앞선 상품을 모두 완료한 뒤에만 이동 (순서대로 작성)
    for (var i = 0; i < index; i++) {
      if (i == _productIndex) {
        if (!_validateCurrentForm()) return;
      } else if (!_isProductDraftComplete(i)) {
        AppToastOverlay.show(context, '${i + 1}번 상품 리뷰를 먼저 작성해 주세요.');
        return;
      }
    }

    _saveCurrentDraft();
    setState(() {
      _productIndex = index;
      _loadDraft(index);
    });
  }

  bool _validateCurrentForm({bool showToast = true}) {
    if (_score1 < 0.1 || _score2 < 0.1 || _score3 < 0.1 || _score4 < 0.1) {
      if (showToast) AppToastOverlay.show(context, '필수 별점을 작성해주세요.');
      return false;
    }
    if (_positiveController.text.trim().length < 20 ||
        _negativeController.text.trim().length < 20) {
      if (showToast) {
        AppToastOverlay.show(context, '필수 리뷰 내용을 작성해주세요. (최소 20자)');
      }
      return false;
    }
    return true;
  }

  /// 필수 별점·필수 본문(각 20자) 충족 시 다음/등록 활성화
  bool get _canProceedCurrent =>
      _score1 >= 0.1 &&
      _score2 >= 0.1 &&
      _score3 >= 0.1 &&
      _score4 >= 0.1 &&
      _positiveController.text.trim().length >= 20 &&
      _negativeController.text.trim().length >= 20;

  Future<void> _onNextProduct() async {
    if (!_validateCurrentForm()) return;
    _saveCurrentDraft();
    setState(() {
      _productIndex += 1;
      _loadDraft(_productIndex);
    });
  }

  void _onPrevProduct() {
    _saveCurrentDraft();
    setState(() {
      _productIndex -= 1;
      _loadDraft(_productIndex);
    });
  }

  Widget _buildProductSection() {
    final item = _currentProduct;
    if (item == null) return const SizedBox.shrink();

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: healthDp(context, 5)),
          _barSectionTitle('주문상품 정보'),
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 14)),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(width: healthDp(context, 1), color: _kBorder),
                borderRadius: BorderRadius.circular(healthDp(context, 12)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _productThumbWidget(item: item),
                SizedBox(width: healthDp(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itName,
                        style: TextStyle(
                          fontFamily: _kFont,
                          fontSize: healthSp(context, 14),
                          fontWeight: FontWeight.w500,
                          height: 1.50,
                          letterSpacing: -1.26,
                          color: _kInk,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 4)),
                      Text(
                        '수량: ${item.ctQty}${item.displayOptionText.isNotEmpty ? ' / ${item.displayOptionText}' : ''}',
                        style: TextStyle(
                          fontFamily: _kFont,
                          color: const Color(0xFF898383),
                          fontSize: healthSp(context, 10),
                          fontWeight: FontWeight.w500,
                          height: 1.80,
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
          padding: EdgeInsets.all(healthDp(context, 14)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _kBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 12)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _productThumbWidget(review: review),
              SizedBox(width: healthDp(context, 12)),
              Expanded(
                child: Text(
                  review.itName ?? review.itId,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: healthSp(context, 14),
                    fontWeight: FontWeight.w500,
                    height: 1.50,
                    letterSpacing: -1.26,
                    color: _kInk,
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
                  width: healthDp(context, 56),
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 10),
                    vertical: healthDp(context, 3),
                  ),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: healthDp(context, _weightLossKg >= 30 ? 1 : 0.5),
                        color: _weightLossKg >= 30
                            ? _kPink
                            : const Color(0xFFD2D2D2),
                      ),
                      borderRadius: BorderRadius.circular(healthDp(context, 8)),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _weightController,
                    focusNode: _weightFocus,
                    readOnly: _weightLossKg < 30,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 3,
                    style: TextStyle(
                      fontFamily: _kFont,
                      color: _kInk,
                      fontSize: healthSp(context, 14),
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                    cursorColor: _kPink,
                    decoration: const InputDecoration(
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onWeightTyped,
                    onEditingComplete: () {
                      _commitWeightText(allowBelow: true);
                      _weightFocus.unfocus();
                    },
                  ),
                ),
                SizedBox(width: healthDp(context, 4)),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final trackH = healthDp(context, 8);
            final thumbR = healthDp(context, 7);
            final labelW = healthDp(context, 36);

            final sliderKg = _weightLossKg.clamp(1, 30);
            double xForKg(int kg) => w <= 0 ? 0 : ((kg - 1) / 29.0) * w;

            void setFromLocalDx(double dx) {
              if (w <= 0) return;
              final t = (dx / w).clamp(0.0, 1.0);
              final kg = (1 + t * 29).round().clamp(1, 30);
              setState(() => _weightLossKg = kg);
              _syncWeightField();
            }

            return Listener(
              onPointerSignal: (event) {
                if (event is! PointerScrollEvent) return;
                if (event.scrollDelta.dx.abs() < event.scrollDelta.dy.abs()) {
                  return;
                }
                // 세로 목록이 가로 휠을 브라우저 뒤로가기로 넘기지 못하게 먼저 막는다.
                event.respond(allowPlatformDefault: false);
                GestureBinding.instance.pointerSignalResolver.register(
                  event,
                  (signal) {
                    if (signal is! PointerScrollEvent) return;
                    if (signal.scrollDelta.dx.abs() < 1) return;
                    final step = signal.scrollDelta.dx > 0 ? 1 : -1;
                    final kg = (_weightLossKg + step).clamp(1, 30);
                    setState(() => _weightLossKg = kg);
                    _syncWeightField();
                  },
                );
              },
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _EagerHorizontalDragRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          _EagerHorizontalDragRecognizer>(
                    () => _EagerHorizontalDragRecognizer(),
                    (instance) {
                      instance.onDown = (d) {
                        setFromLocalDx(d.localPosition.dx);
                      };
                      instance.onUpdate = (d) {
                        setFromLocalDx(d.localPosition.dx);
                      };
                    },
                  ),
                },
                child: Column(
              children: [
                SizedBox(
                  height: thumbR * 2,
                  width: w,
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
                          width: xForKg(sliderKg).clamp(0.0, w).toDouble(),
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
                          left: xForKg(sliderKg) - thumbR,
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
                            kg == 1
                                ? '0'
                                : kg == 30
                                    ? '30+'
                                    : '$kg',
                            textAlign: kg == 1
                                ? TextAlign.left
                                : kg == 30
                                    ? TextAlign.right
                                    : TextAlign.center,
                            style: TextStyle(
                              fontFamily: _kFont,
                              color: xForKg(kg) <= xForKg(sliderKg)
                                  ? _kPink
                                  : _kMuted.withValues(alpha: 0.80),
                              fontSize: healthSp(context, 10),
                              fontWeight: FontWeight.w500,
                              height: 1.60,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
                ),
              ),
            );
          },
        ),
        if (_weightLossKg >= 30) ...[
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
              vertical: healthDp(context, 14),
            ),
            decoration: ShapeDecoration(
              color: const Color(0x0CFF5A8D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
              ),
            ),
            child: Text(
              '30kg 이상은 입력칸에 직접 입력해주세요.',
              style: TextStyle(
                fontFamily: _kFont,
                color: _kPink,
                fontSize: healthSp(context, 12),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSatisfactionSection() {
    final rated = [_score1, _score2, _score3, _score4]
        .where((score) => score >= 0.1)
        .toList();
    final average = rated.isEmpty
        ? 0.0
        : rated.reduce((sum, score) => sum + score) / rated.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle(
          '상품 만족도',
          trailing: '(필수)',
          trailingColor: const Color(0xFFEF4444),
          trailingFontBase: 10,
          gapBase: 6,
          trailingGapBase: 4,
        ),
        SizedBox(height: healthDp(context, 10)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 4),
          ),
          child: Row(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: _kFont,
                  color: _kPink,
                  fontSize: healthSp(context, 32),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: healthDp(context, 8)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppStarRating(
                    rating: average,
                    starSize: healthDp(context, 20.25),
                    gap: healthDp(context, 4),
                    color: _kPink,
                  ),
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    '항목 평균으로 총점이 매겨져요',
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
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Row(
          children: [
            Expanded(
              child: _scoreCard('효과', _score1, (v) => setState(() => _score1 = v)),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: _scoreCard('가성비', _score2, (v) => setState(() => _score2 = v)),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        Row(
          children: [
            Expanded(
              child: _scoreCard('향/맛', _score3, (v) => setState(() => _score3 = v)),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: _scoreCard('편리함', _score4, (v) => setState(() => _score4 = v)),
            ),
          ],
        ),
      ],
    );
  }

  /// 감량 kg 눈금 라벨 (선택은 1~30 1kg 단위)
  static const List<int> _weightLabelMarks = [1, 5, 10, 15, 20, 25, 30];

  /// 효과~편리함 / 상품 만족도 — 0.1 단위 (4.8, 4.2 등)
  double _snapTenthRating(double raw) => appStarSnapTenth(raw);

  /// 감량 kg. 막대는 1~30이고, 30 이상은 입력칸 값이다.
  int _snapWeightKg(int raw) {
    if (raw < 1) return 1;
    if (raw > 999) return 999;
    return raw;
  }

  void _syncWeightField() {
    final text = '$_weightLossKg';
    if (_weightController.text == text) return;
    _weightController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onWeightTyped(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 30) return;
    final kg = _snapWeightKg(n);
    if (kg == _weightLossKg) return;
    setState(() => _weightLossKg = kg);
  }

  void _commitWeightText({required bool allowBelow}) {
    final n = int.tryParse(_weightController.text.trim());
    if (n == null) {
      _syncWeightField();
      return;
    }
    final kg = _snapWeightKg(n);
    if (!allowBelow && kg < 30) {
      _syncWeightField();
      return;
    }
    setState(() => _weightLossKg = kg);
    _syncWeightField();
  }

  Widget _scoreCard(String label, double score, ValueChanged<double> onChanged) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 8),
        healthDp(context, 8),
        healthDp(context, 8),
        healthDp(context, 4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: _kFont,
              color: _kInk,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          AppInteractiveStarRating(
            rating: score,
            onRatingChanged: onChanged,
            starSize: healthDp(context, 25),
            gap: healthDp(context, 2),
            color: _kPink,
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
    bool isLast = false,
  }) {
    final len = controller.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barSectionTitle(
          barTitle,
          trailing: requiredField ? '(필수)' : '(선택)',
          trailingColor: requiredField ? const Color(0xFFEF4444) : _kMuted,
          trailingFontBase: requiredField ? 10 : 12,
          gapBase: requiredField ? 6 : 10,
          trailingGapBase: requiredField ? 4 : 5,
        ),
        SizedBox(height: healthDp(context, 10)),
        HealthFocusOutlineBox(
          height: healthDp(context, 102),
          padding: EdgeInsets.all(healthDp(context, 14)),
          borderRadius: healthDp(context, 7),
          fillColor: Colors.white,
          builder: (focusNode) => Stack(
            children: [
              Positioned.fill(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction:
                      isLast ? TextInputAction.done : TextInputAction.next,
                  maxLines: null,
                  expands: true,
                  maxLength: 500,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: _kInk,
                    height: 1.67,
                    letterSpacing: -0.60,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontFamily: _kFont,
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w300,
                      height: 1.67,
                      letterSpacing: -0.60,
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
                  onFieldSubmitted: (_) {
                    if (isLast) {
                      focusNode.unfocus();
                    } else {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  '$len/500',
                  style: TextStyle(
                    fontFamily: _kFont,
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.50,
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
        _barSectionTitle(
          '사진 업로드',
          trailing: '(선택)',
          trailingColor: _kMuted,
          trailingFontBase: 10,
          gapBase: 6,
          trailingGapBase: 4,
        ),
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
                          child: const ReviewPhotoAddCard(),
                        );
                      },
                    ),
                    if (_draftImages.isNotEmpty)
                      SizedBox(width: healthDp(context, 8)),
                    ..._draftImages.asMap().entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.only(right: healthDp(context, 8)),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 8)),
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
    final isLast = !_isMulti || _productIndex >= _targetProducts.length - 1;
    final isFirst = !_isMulti || _productIndex <= 0;
    final leftLabel = _isEditMode ? '취소' : '이전';
    final rightLabel =
        _isEditMode ? '수정' : (_isMulti ? (isLast ? '완료' : '다음') : '완료');

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 20),
          healthDp(context, 10),
          healthDp(context, 20),
          healthDp(context, 10),
        ),
        color: Colors.white,
        child: Row(
          children: [
            SizedBox(
              width: healthDp(context, 130),
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
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_isMulti && !isFirst) {
                            _onPrevProduct();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(
                    leftLabel,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _kFont,
                      color: _kMuted,
                      fontSize: healthSp(context, 16),
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: Container(
                height: healthDp(context, 40),
                decoration: ShapeDecoration(
                  color: _canProceedCurrent ? _kPink : const Color(0xFFD2D2D2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: TextButton(
                  onPressed: (_isLoading || !_canProceedCurrent)
                      ? null
                      : () {
                          if (_isMulti && !isLast) {
                            _onNextProduct();
                          } else {
                            AppActionGate.protect(_submitReview);
                          }
                        },
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
                          rightLabel,
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
    if (_isMulti) {
      if (!_validateCurrentForm()) return;
      _saveCurrentDraft();
      for (var i = 0; i < _targetProducts.length; i++) {
        if (i == _productIndex) continue;
        final d = _drafts[i];
        if (d == null ||
            d.score1 < 0.1 ||
            d.score2 < 0.1 ||
            d.score3 < 0.1 ||
            d.score4 < 0.1 ||
            d.positive.trim().length < 20 ||
            d.negative.trim().length < 20) {
          AppToastOverlay.show(context, '${i + 1}번 상품 리뷰를 완료해 주세요.');
          _goToProductIndex(i);
          return;
        }
      }
    } else {
      if (!_formKey.currentState!.validate()) {
        AppToastOverlay.show(context, '필수 항목을 작성해주세요.');
        return;
      }
      if (!_validateCurrentForm()) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }

      if (_isEditMode) {
        final editTarget = widget.initialReview;
        final itId = editTarget?.itId ?? _currentProduct?.itId;
        if (itId == null || itId.isEmpty) {
          return;
        }
        final imagePaths = await _resolveImagePathsForSubmit();
        if (imagePaths.length != _draftImages.length) {
          return;
        }
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
          isRvkind: editTarget?.isRvkind ?? 'prescription',
          isRecommend: editTarget?.isRecommend ?? 'y',
          isPositiveReviewText: _positiveController.text,
          isNegativeReviewText: _negativeController.text.isNotEmpty
              ? _negativeController.text
              : null,
          isMoreReviewText: _moreController.text.trim(),
          images: imagePaths,
          isPayMthod: 'solo',
          isOutageNum: _weightLossKg,
        );
        final result = editTarget?.isId != null
            ? await ReviewService.updateReview(editTarget!.isId!, review)
            : await ReviewService.createReview(review);
        if (!mounted) return;
        final message = (result['message'] as String?)?.trim();
        if (result['success'] == true) {
          AppToastOverlay.show(
            context,
            (message != null && message.isNotEmpty) ? message : '리뷰가 수정되었습니다.',
          );
          Navigator.pop(context, true);
        } else {
          AppToastOverlay.show(
            context,
            (message != null && message.isNotEmpty)
                ? message
                : '리뷰 수정에 실패했습니다.',
          );
        }
        return;
      }

      int? createdId;
      for (var i = 0; i < _targetProducts.length; i++) {
        late final double s1, s2, s3, s4;
        late final int weight;
        late final String positive, negative, more;
        late final List<_ReviewDraftImage> imgs;
        if (i == _productIndex) {
          s1 = _score1;
          s2 = _score2;
          s3 = _score3;
          s4 = _score4;
          weight = _weightLossKg;
          positive = _positiveController.text;
          negative = _negativeController.text;
          more = _moreController.text;
          imgs = List<_ReviewDraftImage>.from(_draftImages);
        } else {
          final d = _drafts[i]!;
          s1 = d.score1;
          s2 = d.score2;
          s3 = d.score3;
          s4 = d.score4;
          weight = d.weightLossKg;
          positive = d.positive;
          negative = d.negative;
          more = d.more;
          imgs = d.images;
        }

        final uploadFutures = imgs.map((draft) async {
          if (draft.isServer) return draft.serverPath!.trim();
          if (draft.file == null) return null;
          return ReviewService.uploadReviewImage(draft.file!);
        }).toList();
        final uploadResults = await Future.wait(uploadFutures);
        final paths = uploadResults
            .whereType<String>()
            .where((u) => u.isNotEmpty)
            .toList();
        if (paths.length !=
            imgs.where((d) => d.isServer || d.file != null).length) {
          if (mounted) {
            AppToastOverlay.show(context, '${i + 1}번 상품 이미지 업로드에 실패했습니다.');
          }
          return;
        }

        final item = _targetProducts[i];
        final review = ReviewModel(
          mbId: user.id,
          odId: widget.orderDetail?.odId,
          itId: item.itId,
          isName: user.name,
          isScore1: _snapTenthRating(s1),
          isScore2: _snapTenthRating(s2),
          isScore3: _snapTenthRating(s3),
          isScore4: _snapTenthRating(s4),
          isRvkind: 'prescription',
          isRecommend: 'y',
          isPositiveReviewText: positive,
          isNegativeReviewText: negative.isNotEmpty ? negative : null,
          isMoreReviewText: more.trim(),
          images: paths,
          isPayMthod: 'solo',
          isOutageNum: weight,
        );
        final result = await ReviewService.createReview(review);
        final created = result['review'];
        if (created is ReviewModel && created.isId != null) {
          createdId = created.isId;
        }
        if (result['success'] != true) {
          if (mounted) {
            final message = (result['message'] as String?)?.trim();
            AppToastOverlay.show(
              context,
              (message != null && message.isNotEmpty)
                  ? message
                  : '${i + 1}번 상품 리뷰 작성에 실패했습니다.',
            );
          }
          return;
        }
      }

      if (!mounted) return;
      AppToastOverlay.show(context, '리뷰가 작성되었습니다.');
      openMyReviewsAfterWrite(context, focusIsId: createdId);
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(
          context,
          _isEditMode ? '리뷰 수정 중 오류가 발생했습니다.' : '리뷰 작성 중 오류가 발생했습니다.',
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

/// 감량 막대 드래그가 화면 뒤로가기(가장자리 스와이프)에 지지 않도록 바로 제스처를 가져간다.
class _EagerHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
