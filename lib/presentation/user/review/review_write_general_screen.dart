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

/// 리뷰 작성 화면용 사진 슬롯 (기존 URL 또는 새로 고른 파일)
class _ReviewDraftImage {
  _ReviewDraftImage({this.file, this.serverPath});

  final XFile? file;
  final String? serverPath;

  bool get isServer =>
      serverPath != null && serverPath!.trim().isNotEmpty;
}

/// 일반 상품 리뷰 — 본문 `is_positive_review_text`, 별점 `total_is_score` 만 사용
class ReviewWriteGeneralScreen extends StatefulWidget {
  final OrderDetailModel? orderDetail;
  final ReviewModel? initialReview;
  final List<OrderItem>? selectedProducts;

  ReviewWriteGeneralScreen({
    super.key,
    required OrderDetailModel orderDetail,
    this.selectedProducts,
  })  : orderDetail = orderDetail,
        initialReview = null;

  ReviewWriteGeneralScreen.edit({
    super.key,
    required ReviewModel review,
  })  : orderDetail = null,
        initialReview = review,
        selectedProducts = null;

  bool get _isEditMode => initialReview != null;

  @override
  State<ReviewWriteGeneralScreen> createState() => _ReviewWriteGeneralScreenState();
}

class _GeneralReviewDraft {
  double score = 0;
  String text = '';
  List<_ReviewDraftImage> images = [];
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
  late final VoidCallback _reviewTextListener;

  int _productIndex = 0;
  final Map<int, _GeneralReviewDraft> _drafts = {};

  List<OrderItem> get _targetProducts {
    final selected = widget.selectedProducts;
    if (selected != null && selected.isNotEmpty) return selected;
    final od = widget.orderDetail;
    if (od == null || od.products.isEmpty) return const [];
    return od.products
        .where((p) {
          if (p.itId.trim().isEmpty) return false;
          final parent = (p.parent ?? '').trim();
          if (parent.isNotEmpty) return false;
          final kind = (p.ctKind ?? '').toLowerCase().trim();
          if (kind.startsWith('supply_add|')) return false;
          return true;
        })
        .toList();
  }

  bool get _isMulti => !widget._isEditMode && _targetProducts.length > 1;

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

  void _goToProductIndex(int index) {
    if (index == _productIndex) return;
    _saveCurrentDraft();
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
    if (!_validateCurrent()) return;
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

  Widget _buildProductTabs() {
    final list = _targetProducts;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) SizedBox(width: healthDp(context, 8)),
            GestureDetector(
              onTap: () => _goToProductIndex(i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 12),
                  vertical: healthDp(context, 4),
                ),
                decoration: ShapeDecoration(
                  color: i == _productIndex ? _kPink : Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      color:
                          i == _productIndex ? _kPink : const Color(0xFFD2D2D2),
                    ),
                    borderRadius: BorderRadius.circular(healthDp(context, 999)),
                  ),
                ),
                child: Text(
                  '${i + 1}번 상품',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == _productIndex ? Colors.white : _kMuted,
                    fontSize: healthSp(context, 11),
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
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
            (message != null && message.isNotEmpty)
                ? message
                : '리뷰가 수정되었습니다.',
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

      for (var i = 0; i < _targetProducts.length; i++) {
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

        final paths = <String>[];
        for (final draft in imgs) {
          if (draft.isServer) {
            paths.add(draft.serverPath!.trim());
          } else if (draft.file != null) {
            final uploaded =
                await ReviewService.uploadReviewImage(draft.file!);
            if (uploaded == null || uploaded.isEmpty) {
              if (mounted) {
                AppToastOverlay.show(
                    context, '${i + 1}번 상품 이미지 업로드에 실패했습니다.');
              }
              return;
            }
            paths.add(uploaded);
          }
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
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(
          context,
          widget._isEditMode
              ? '리뷰 수정 중 오류가 발생했습니다.'
              : '리뷰 작성 중 오류가 발생했습니다.',
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(
                        top: healthDp(context, 20),
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
                              if (!widget._isEditMode && _isMulti) ...[
                                _buildProductTabs(),
                                SizedBox(height: healthDp(context, 20)),
                              ],
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
                            ],
                          ),
                        ),
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
    final isLast = !_isMulti || _productIndex >= _targetProducts.length - 1;
    final isFirst = !_isMulti || _productIndex <= 0;
    final leftLabel = _isMulti ? (isFirst ? '취소' : '이전') : '취소';
    final rightLabel = widget._isEditMode
        ? '수정'
        : (_isMulti ? (isLast ? '등록' : '다음') : '등록');

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
                  side: BorderSide(
                    color: const Color(0xFFD2D2D2),
                    width: healthDp(context, 0.5),
                  ),
                  minimumSize: Size.fromHeight(healthDp(context, 40)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  leftLabel,
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
                onPressed: (_isLoading || !_canProceedCurrent)
                    ? null
                    : () {
                        if (_isMulti && !isLast) {
                          _onNextProduct();
                        } else {
                          _submit();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPink,
                  disabledBackgroundColor: const Color(0xFFE9E9E9),
                  disabledForegroundColor: _kMuted,
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
                          color: _canProceedCurrent ? Colors.white : _kMuted,
                          fontSize: healthSp(context, 16),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
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
  double _snapTenthRating(double raw) => appStarSnapTenth(raw);

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
          AppInteractiveStarRating(
            rating: _score,
            onRatingChanged: (v) => setState(() => _score = v),
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

  Widget _reviewInputBlock(BuildContext context) {
    final len = _reviewController.text.length;
    final meetsMin = len >= 20;
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
              maxLines: null,
              expands: true,
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
              right: healthDp(context, 56),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$len자',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(width: healthDp(context, 6)),
                Container(
                  width: healthDp(context, 16),
                  height: healthDp(context, 16),
                  decoration: BoxDecoration(
                    color: meetsMin
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    meetsMin ? Icons.check : Icons.close,
                    size: healthDp(context, 11),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                Builder(
                  builder: (anchorContext) {
                    return InkWell(
                      onTap: () => _openPhotoSourceDropdown(anchorContext),
                      child: Container(
                        width: img,
                        height: img,
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
          ),
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
