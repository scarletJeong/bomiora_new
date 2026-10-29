import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/navigation/app_action_gate.dart';
import '../../../core/utils/image_picker_utils.dart';
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

/// 리뷰 작성 화면용 사진 슬롯 (기존 URL 또는 새로 고른 파일)
class _ReviewDraftImage {
  _ReviewDraftImage({this.file, this.serverPath, this.previewBytes});

  final XFile? file;
  final String? serverPath;
  final Uint8List? previewBytes;

  bool get isServer => serverPath != null && serverPath!.trim().isNotEmpty;
}

/// 일반 상품 리뷰 — 본문 `is_positive_review_text`, 별점 `total_is_score` 만 사용
class ReviewWriteGeneralScreen extends StatefulWidget {
  final OrderDetailModel? orderDetail;
  final ReviewModel? initialReview;
  final List<OrderItem>? selectedProducts;
  final List<String> reviewedItIds;
  final List<ReviewModel> existingReviews;

  ReviewWriteGeneralScreen({
    super.key,
    required OrderDetailModel orderDetail,
    this.selectedProducts,
    this.reviewedItIds = const [],
    this.existingReviews = const [],
  })  : orderDetail = orderDetail,
        initialReview = null;

  ReviewWriteGeneralScreen.edit({
    super.key,
    required ReviewModel review,
  })  : orderDetail = null,
        initialReview = review,
        selectedProducts = null,
        reviewedItIds = const [],
        existingReviews = const [];

  bool get _isEditMode => initialReview != null;

  @override
  State<ReviewWriteGeneralScreen> createState() =>
      _ReviewWriteGeneralScreenState();
}

class _GeneralReviewDraft {
  double score = 0;
  String text = '';
  List<_ReviewDraftImage> images = [];
}

class _ReviewWriteGeneralScreenState extends State<ReviewWriteGeneralScreen> {
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kInk = Color(0xFF1A1A1E);
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
  late final VoidCallback _reviewTextListener;

  int _productIndex = 0;
  final Map<int, _GeneralReviewDraft> _drafts = {};

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

  bool get _isMulti => !widget._isEditMode && _targetProducts.length > 1;

  Set<String> get _reviewedIds => widget.reviewedItIds
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  bool _isReviewedIndex(int index) {
    if (index < 0 || index >= _targetProducts.length) return false;
    return _reviewedIds.contains(_targetProducts[index].itId.trim());
  }

  bool get _isCurrentReviewed => _isReviewedIndex(_productIndex);

  int get _firstWritableIndex {
    for (var i = 0; i < _targetProducts.length; i++) {
      if (!_isReviewedIndex(i)) return i;
    }
    return 0;
  }

  bool get _hasLaterWritable {
    for (var i = _productIndex + 1; i < _targetProducts.length; i++) {
      if (!_isReviewedIndex(i)) return true;
    }
    return false;
  }

  ReviewModel? _existingAt(int index) {
    if (!_isReviewedIndex(index)) return null;
    final id = _targetProducts[index].itId.trim();
    for (final review in widget.existingReviews) {
      if (review.itId.trim() == id) return review;
    }
    return null;
  }

  OrderItem? get _firstOrderItem {
    final list = _targetProducts;
    if (list.isEmpty) return null;
    return list[_productIndex.clamp(0, list.length - 1)];
  }

  ReviewModel? get _editReview => widget.initialReview;

  @override
  void initState() {
    super.initState();
    _reviewTextListener = () {
      if (!mounted) return;
      setState(() {
        if (_reviewBodyError != null &&
            _reviewController.text.trim().length >= 20) {
          _reviewBodyError = null;
        }
      });
    };
    _reviewController.addListener(_reviewTextListener);
    _productIndex = _firstWritableIndex;

    final r = widget.initialReview;
    if (r != null) {
      final positive = r.isPositiveReviewText?.trim() ?? '';
      final more = r.isMoreReviewText?.trim() ?? '';
      _reviewController.text = positive.isNotEmpty ? positive : more;
      _score = _snapTenthRating(r.averageScore ?? 0);
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

  void _saveCurrentDraft() {
    _drafts[_productIndex] = _GeneralReviewDraft()
      ..score = _score
      ..text = _reviewController.text
      ..images = List<_ReviewDraftImage>.from(_draftImages);
  }

  void _loadDraft(int index) {
    final existing = _existingAt(index);
    if (existing != null) {
      _applyExistingReview(existing);
      return;
    }
    final d = _drafts[index];
    if (d == null) {
      _score = 0;
      _reviewController.clear();
      _draftImages.clear();
      _reviewBodyError = null;
      return;
    }
    _score = d.score;
    _reviewController.text = d.text;
    _draftImages
      ..clear()
      ..addAll(d.images);
    _reviewBodyError = null;
  }

  void _applyExistingReview(ReviewModel review) {
    final positive = review.isPositiveReviewText?.trim() ?? '';
    final more = review.isMoreReviewText?.trim() ?? '';
    _reviewController.text = positive.isNotEmpty ? positive : more;
    _score = _snapTenthRating(review.totalIsScore ?? review.averageScore ?? 0);
    _draftImages
      ..clear()
      ..addAll(
        review.images
            .take(_maxImages)
            .map((path) => _ReviewDraftImage(serverPath: path)),
      );
    _reviewBodyError = null;
  }

  void _goToProductIndex(int index) {
    if (index == _productIndex) return;

    final targetReviewed = _isReviewedIndex(index);
    if (!targetReviewed) {
      for (var i = 0; i < index; i++) {
        if (_isReviewedIndex(i)) continue;
        if (i == _productIndex) {
          if (!_validateCurrent()) return;
        } else if (!_isProductDraftComplete(i)) {
          AppToastOverlay.show(context, '${i + 1}번 상품 리뷰를 먼저 작성해 주세요.');
          return;
        }
      }
    }

    if (!_isCurrentReviewed) _saveCurrentDraft();
    setState(() {
      _productIndex = index;
      _loadDraft(index);
    });
  }

  bool _validateCurrent({bool showToast = true}) {
    final text = _reviewController.text.trim();
    if (_score < 0.1) {
      if (showToast) {
        AppToastOverlay.show(context, '상품 만족도 통합합 별점을 작성해주세요.');
      }
      return false;
    }
    if (text.length < 20) {
      setState(() => _reviewBodyError = '최소 20자 이상 작성해주세요.');
      if (showToast) {
        AppToastOverlay.show(context, '필수 리뷰 내용을 작성해주세요. (최소 20자)');
      }
      return false;
    }
    return true;
  }

  /// 별점·본문(20자) 충족 시 다음/등록 활성화
  bool get _canProceedCurrent =>
      _score >= 0.1 && _reviewController.text.trim().length >= 20;

  Future<void> _onNextProduct() async {
    if (!_isCurrentReviewed && !_validateCurrent()) return;
    if (!_isCurrentReviewed) _saveCurrentDraft();
    setState(() {
      _productIndex += 1;
      _loadDraft(_productIndex);
    });
  }

  void _onNextFromReviewed() {
    if (_productIndex < _targetProducts.length - 1) {
      setState(() {
        _productIndex += 1;
        _loadDraft(_productIndex);
      });
      return;
    }
    final next = _firstWritableIndex;
    if (next != _productIndex) {
      setState(() {
        _productIndex = next;
        _loadDraft(next);
      });
      return;
    }
    Navigator.pop(context);
  }

  void _onPrevProduct() {
    _saveCurrentDraft();
    setState(() {
      _productIndex -= 1;
      _loadDraft(_productIndex);
    });
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
    if (_isReviewedIndex(index)) return true;
    if (index == _productIndex) return _canProceedCurrent;
    final d = _drafts[index];
    if (d == null) return false;
    return d.score >= 0.1 && d.text.trim().length >= 20;
  }

  Widget _buildProductStepChip(int index) {
    final reviewed = _isReviewedIndex(index);
    final kind = _productStepKind(index);
    final label = '${index + 1}번 상품';
    final showIcon = reviewed || kind != 2;

    late final Color bg;
    late final Color border;
    late final Color textColor;
    List<BoxShadow>? shadows;

    if (reviewed) {
      final selected = index == _productIndex;
      bg = const Color(0xFFE6E6E6);
      border = selected ? const Color(0xFF8E8E8E) : const Color(0xFFD0D0D0);
      textColor = const Color(0xFF8A8A8A);
      shadows = null;
    } else {
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

  Widget _draftImageThumb(
      BuildContext context, _ReviewDraftImage draft, double size) {
    if (draft.isServer) {
      final url = ImageUrlHelper.getImageUrl(draft.serverPath);
      return Image.network(
        url,
        key: ValueKey(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(size),
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
    final edit = _editReview;
    if (widget._isEditMode) {
      if (edit == null || edit.isId == null) return;
    } else if (_targetProducts.isEmpty) {
      return;
    }

    if (_isMulti) {
      if (!_validateCurrent()) return;
      _saveCurrentDraft();
      for (var i = 0; i < _targetProducts.length; i++) {
        if (_isReviewedIndex(i)) continue;
        if (i == _productIndex) continue;
        final d = _drafts[i];
        if (d == null || d.score < 0.1 || d.text.trim().length < 20) {
          AppToastOverlay.show(context, '${i + 1}번 상품 리뷰를 완료해 주세요.');
          _goToProductIndex(i);
          return;
        }
      }
    } else {
      if (!_validateCurrent()) return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        return;
      }

      if (widget._isEditMode) {
        final paths = await _resolveImagePathsForSubmit();
        if (paths.length != _draftImages.length) {
          return;
        }
        final review = ReviewModel(
          isId: edit!.isId,
          mbId: user.id,
          odId: edit.odId ?? widget.orderDetail?.odId,
          itId: edit.itId,
          isName: user.name,
          isScore1: edit.isScore1,
          isScore2: edit.isScore2,
          isScore3: edit.isScore3,
          isScore4: edit.isScore4,
          totalIsScore: _snapTenthRating(_score),
          isRvkind: 'general',
          isRecommend: edit.isRecommend ?? 'y',
          isPositiveReviewText: _reviewController.text.trim(),
          isNegativeReviewText: edit.isNegativeReviewText ?? '',
          isMoreReviewText: edit.isMoreReviewText ?? '',
          images: paths,
          isPayMthod: 'solo',
        );
        final result = await ReviewService.updateReview(edit.isId!, review);
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
        if (_isReviewedIndex(i)) continue;
        late final double score;
        late final String text;
        late final List<_ReviewDraftImage> imgs;
        if (i == _productIndex) {
          score = _score;
          text = _reviewController.text.trim();
          imgs = List<_ReviewDraftImage>.from(_draftImages);
        } else {
          final d = _drafts[i]!;
          score = d.score;
          text = d.text.trim();
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
          isScore1: 0,
          isScore2: 0,
          isScore3: 0,
          isScore4: 0,
          totalIsScore: _snapTenthRating(score),
          isRvkind: 'general',
          isRecommend: 'y',
          isPositiveReviewText: text,
          isNegativeReviewText: '',
          isMoreReviewText: '',
          images: paths,
          isPayMthod: 'solo',
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
          widget._isEditMode ? '리뷰 수정 중 오류가 발생했습니다.' : '리뷰 작성 중 오류가 발생했습니다.',
        );
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
              title: widget._isEditMode ? '리뷰수정' : '리뷰쓰기',
              leadingIconSize: healthDp(context, 16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!widget._isEditMode && _isMulti)
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
                      padding: EdgeInsets.only(
                        top: healthDp(context, 10),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 20),
                          ),
                          child: IgnorePointer(
                            ignoring: _isCurrentReviewed,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                              _barSectionTitle(context, '주문상품 정보'),
                              SizedBox(height: healthDp(context, 10)),
                              _productCard(context, item, edit),
                              SizedBox(height: healthDp(context, 24)),
                              _barSectionTitle(
                                context,
                                '상품 만족도',
                                trailing: '(필수)',
                                trailingColor: const Color(0xFFEF4444),
                                trailingSize: 10,
                                barGap: 6,
                              ),
                              SizedBox(height: healthDp(context, 10)),
                              _scoreCard(context),
                              SizedBox(height: healthDp(context, 24)),
                              _barSectionTitle(
                                context,
                                '상품 리뷰',
                                trailing: '(필수)',
                                trailingColor: const Color(0xFFEF4444),
                                trailingSize: 10,
                                barGap: 6,
                              ),
                              SizedBox(height: healthDp(context, 10)),
                              _reviewInputBlock(context),
                              SizedBox(height: healthDp(context, 24)),
                              _barSectionTitle(
                                context,
                                '사진 업로드',
                                trailing: '(선택)',
                                trailingColor: _kMuted,
                                trailingSize: 10,
                                barGap: 6,
                              ),
                              SizedBox(height: healthDp(context, 10)),
                              _imageSection(context),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 24)),
                        const ReviewPolicyFooter(),
                      ],
                    ),
                  ),
                  _bottomActionBar(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomActionBar(BuildContext context) {
    if (_isCurrentReviewed) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 20),
            healthDp(context, 5),
            healthDp(context, 20),
            healthDp(context, 5),
          ),
          child: SizedBox(
            height: healthDp(context, 40),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onNextFromReviewed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPink,
                disabledBackgroundColor: const Color(0xFFD2D2D2),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
              ),
              child: Text(
                '다음',
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
      );
    }

    final isFirst = !_isMulti || _productIndex <= 0;
    final leftLabel = (_isMulti && !isFirst) ? '이전' : '취소';
    final rightLabel = widget._isEditMode
        ? '수정'
        : (_isMulti && _hasLaterWritable)
            ? '다음'
            : '리뷰 등록하기';

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 20),
          healthDp(context, 5),
          healthDp(context, 20),
          healthDp(context, 5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: healthDp(context, 130),
              height: healthDp(context, 40),
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_isMulti && !isFirst) {
                          _onPrevProduct();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: const Color(0xFFD2D2D2),
                    width: healthDp(context, 0.5),
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: Size(healthDp(context, 130), healthDp(context, 40)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  leftLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
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
            SizedBox(width: healthDp(context, 8)),
            Expanded(
              child: SizedBox(
                height: healthDp(context, 40),
                child: ElevatedButton(
                  onPressed: (_isLoading || !_canProceedCurrent)
                      ? null
                      : () {
                          if (_isMulti && _hasLaterWritable) {
                            _onNextProduct();
                          } else {
                            AppActionGate.protect(_submit);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPink,
                    disabledBackgroundColor: const Color(0xFFD2D2D2),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.fromHeight(healthDp(context, 40)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
                          rightLabel,
                          style: TextStyle(
                            fontFamily: _kFont,
                            color: Colors.white,
                            fontSize: healthSp(context, 16),
                            fontWeight: FontWeight.w500,
                            height: 1,
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

  /// 검정 세로 막대 + 제목. `trailing` 은 제목 바로 뒤 `(필수)` / `(선택)`.
  Widget _barSectionTitle(
    BuildContext context,
    String title, {
    String? trailing,
    Color? trailingColor,
    double trailingSize = 10,
    double barGap = 10,
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
        SizedBox(width: healthDp(context, barGap)),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, 14),
              fontWeight: FontWeight.w500,
              letterSpacing: healthSp(context, -1.26),
              color: _kInk,
              height: 1,
            ),
          ),
        ),
        if (trailing != null && trailing.isNotEmpty) ...[
          SizedBox(width: healthDp(context, 4)),
          Text(
            trailing,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: healthSp(context, trailingSize),
              fontWeight: FontWeight.w300,
              color: trailingColor ?? _kMuted,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _productThumbForEdit(BuildContext context, ReviewModel r) {
    final side = healthDp(context, 64);
    final r4 = BorderRadius.circular(healthDp(context, 8));
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
    final raw = r.productImage?.trim();
    if (raw != null &&
        raw.isNotEmpty &&
        !ImageUrlHelper.isReviewAttachmentUrl(raw)) {
      final normalized =
          ImageUrlHelper.normalizeThumbnailUrl(raw, r.itId) ?? raw;
      if (ImageUrlHelper.isReviewAttachmentUrl(normalized)) {
        return fallback();
      }
      final u = ImageUrlHelper.getImageUrl(normalized);
      if (!u.toLowerCase().contains('no_img.png') &&
          !ImageUrlHelper.isReviewAttachmentUrl(u)) {
        return ClipRRect(
          borderRadius: r4,
          child: Image.network(
            u,
            key: ValueKey(u),
            width: side,
            height: side,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      }
    }
    return fallback();
  }

  Widget _productCard(
      BuildContext context, OrderItem? item, ReviewModel? edit) {
    if (item != null) {
      final option = item.displayOptionText.trim();
      final optionLine = option.isNotEmpty
          ? (item.ctQty > 0 ? '$option : ${item.ctQty}개' : option)
          : (item.ctQty > 0 ? '${item.ctQty}개' : '');
      return Container(
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
            ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
              child: SizedBox(
                width: healthDp(context, 64),
                height: healthDp(context, 64),
                child: () {
                  final raw = item.imageUrl?.trim() ?? '';
                  final url = raw.isEmpty
                      ? null
                      : ImageUrlHelper.normalizeThumbnailUrl(raw, item.itId);
                  if (url == null || url.isEmpty) {
                    return Container(
                      color: const Color(0xFFE9E9E9),
                      child: Icon(
                        Icons.image_outlined,
                        color: _kMuted,
                        size: healthDp(context, 24),
                      ),
                    );
                  }
                  return Image.network(
                    url,
                    key: ValueKey('${item.itId}|$url'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE9E9E9),
                      child: Icon(
                        Icons.image_outlined,
                        color: _kMuted,
                        size: healthDp(context, 24),
                      ),
                    ),
                  );
                }(),
              ),
            ),
            SizedBox(width: healthDp(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itName,
                    style: TextStyle(
                      fontFamily: _kFont,
                      color: _kInk,
                      fontSize: healthSp(context, 14),
                      fontWeight: FontWeight.w500,
                      letterSpacing: healthSp(context, -1.26),
                    ),
                  ),
                  if (optionLine.isNotEmpty) ...[
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      optionLine,
                      style: TextStyle(
                        fontFamily: _kFont,
                        color: const Color(0xFF898383),
                        fontSize: healthSp(context, 10),
                        fontWeight: FontWeight.w500,
                        height: 1.80,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (edit != null) {
      return Container(
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
            _productThumbForEdit(context, edit),
            SizedBox(width: healthDp(context, 12)),
            Expanded(
              child: Text(
                edit.itName ?? edit.itId,
                style: TextStyle(
                  fontFamily: _kFont,
                  color: _kInk,
                  fontSize: healthSp(context, 14),
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -1.26),
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
  double _snapTenthRating(double raw) => appStarSnapTenth(raw);

  Widget _scoreCard(BuildContext context) {
    final scoreText = _score.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: healthDp(context, 4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                scoreText,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: _kFont,
                  color: _kPink,
                  fontSize: healthSp(context, 32),
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              SizedBox(width: healthDp(context, 8)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppStarRating(
                    rating: _score,
                    starSize: healthDp(context, 20.25),
                    gap: healthDp(context, 1),
                    color: _kPink,
                    preciseFill: true,
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  Text(
                    '받아본 상품은 어떠셨나요?',
                    style: TextStyle(
                      fontFamily: _kFont,
                      color: _kMuted,
                      fontSize: healthSp(context, 10),
                      fontWeight: FontWeight.w300,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
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
          child: Row(
            children: [
              Text(
                '효과',
                style: TextStyle(
                  fontFamily: _kFont,
                  color: _kInk,
                  fontSize: healthSp(context, 12),
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              const Spacer(),
              AppInteractiveStarRating(
                rating: _score,
                onRatingChanged: (v) => setState(() => _score = v),
                starSize: healthDp(context, 25),
                gap: healthDp(context, 1),
                color: _kPink,
                alignment: MainAxisAlignment.end,
                snapMode: AppStarSnapMode.tenth,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewInputBlock(BuildContext context) {
    final len = _reviewController.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HealthFocusOutlineBox(
          height: healthDp(context, 102),
          padding: EdgeInsets.all(healthDp(context, 14)),
          borderRadius: healthDp(context, 7),
          fillColor: Colors.white,
          hasError: _reviewBodyError != null,
          builder: (focusNode) => Column(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _reviewController,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  maxLines: null,
                  expands: true,
                  maxLength: 500,
                  onChanged: (_) {
                    setState(() {
                      if (_reviewController.text.trim().length >= 20) {
                        _reviewBodyError = null;
                      }
                    });
                  },
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w300,
                    color: _kInk,
                    letterSpacing: healthSp(context, -0.60),
                    height: 1.67,
                  ),
                  decoration: InputDecoration(
                    hintText: '상품 리뷰를 작성해주세요. (최소 20자)',
                    hintStyle: TextStyle(
                      fontFamily: _kFont,
                      color: _kMuted,
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w300,
                      letterSpacing: healthSp(context, -0.60),
                      height: 1.67,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onFieldSubmitted: (_) => focusNode.unfocus(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$len/500',
                  style: TextStyle(
                    fontFamily: _kFont,
                    color: _reviewController.text.trim().length >= 20
                        ? const Color(0xFF16A34A)
                        : _kMuted,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                    letterSpacing: healthSp(context, -0.50),
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_reviewBodyError != null) ...[
          SizedBox(height: healthDp(context, 6)),
          Text(
            _reviewBodyError!,
            style: TextStyle(
              fontFamily: _kFont,
              color: const Color(0xFFEF4444),
              fontSize: healthSp(context, 10),
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );
  }

  Widget _imageSection(BuildContext context) {
    final img = healthDp(context, 76);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: img,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!_isCurrentReviewed)
                  Builder(
                    builder: (anchorContext) {
                      return InkWell(
                        onTap: () => _openPhotoSourceDropdown(anchorContext),
                        child: const ReviewPhotoAddCard(),
                      );
                    },
                  ),
                if (!_isCurrentReviewed && _draftImages.isNotEmpty)
                  SizedBox(width: healthDp(context, 8)),
                ..._draftImages.asMap().entries.map((e) {
                  return Padding(
                    padding: EdgeInsets.only(right: healthDp(context, 8)),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 8)),
                          child: _draftImageThumb(context, e.value, img),
                        ),
                        if (!_isCurrentReviewed)
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
          ),
        ),
        SizedBox(height: healthDp(context, 12)),
        Text(
          '최대 3장 / 파일당 5MB이하(GIF,JPG,PNG)',
          style: TextStyle(
            fontFamily: _kFont,
            color: _kMuted,
            fontSize: healthSp(context, 10),
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
      ],
    );
  }
}
