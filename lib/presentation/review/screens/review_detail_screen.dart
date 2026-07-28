import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/review/review_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../common/widgets/app_star_rating.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';

/// 리뷰 상세 — 서포터/일반 공통 UI (배지·도움쿠폰은 서포터만)
class ReviewDetailScreen extends StatefulWidget {
  final ReviewModel review;
  final bool fromProductDetail;

  const ReviewDetailScreen({
    super.key,
    required this.review,
    this.fromProductDetail = false,
  });

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _muted = Color(0xFF898686);
  static const Color _muted2 = Color(0xFF898383);
  static const Color _border = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  late ReviewModel _review;
  bool _isLoading = false;
  int _imagePage = 0;
  final PageController _imageController = PageController();

  bool get _isSupporter => _review.isSupporterReview;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  double get _displayScore => _review.averageScore ?? 0;

  String get _scoreText {
    final s = _displayScore;
    if (s <= 0) return '0';
    if ((s * 10).round() % 10 == 0) return s.toStringAsFixed(0);
    return s.toStringAsFixed(1);
  }

  int _pct(double score) => (score.clamp(0, 5) * 20).round();

  String get _writtenDate {
    final t = _review.isTime;
    if (t == null) return '';
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y.$m.$d 작성';
  }

  String? get _productThumb {
    final product = _review.productImage?.trim();
    if (product != null && product.isNotEmpty) {
      return ImageUrlHelper.getImageUrl(product);
    }
    if (_review.images.isNotEmpty) {
      return ImageUrlHelper.getReviewImageUrl(_review.images.first);
    }
    return null;
  }

  List<String> get _reviewImages => _review.images
      .map(ImageUrlHelper.getReviewImageUrl)
      .where((u) => u.trim().isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final padH = healthDp(context, 27);
    final title = _isSupporter ? '서포터 리뷰' : '사용자 리뷰';

    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(title: title, centerTitle: false),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          padH,
          healthDp(context, 20),
          padH,
          healthDp(context, 40),
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 15),
            vertical: healthDp(context, 20),
          ),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _border),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductHeader(context),
              SizedBox(height: healthDp(context, 20)),
              _buildScoreRow(context),
              if (_reviewImages.isNotEmpty) ...[
                SizedBox(height: healthDp(context, 20)),
                _buildImageCarousel(context),
              ],
              SizedBox(height: healthDp(context, 20)),
              _buildAuthorBlock(context),
              SizedBox(height: healthDp(context, 20)),
              if (_review.isGeneralReview)
                _buildTextSection(
                  context,
                  title: '리뷰',
                  body: _review.isPositiveReviewText,
                )
              else ...[
                _buildTextSection(
                  context,
                  title: '좋았던 점',
                  body: _review.isPositiveReviewText,
                ),
                SizedBox(height: healthDp(context, 10)),
                _buildTextSection(
                  context,
                  title: '아쉬운 점',
                  body: _review.isNegativeReviewText,
                ),
                SizedBox(height: healthDp(context, 10)),
                _buildTextSection(
                  context,
                  title: '꿀팁',
                  body: _review.isMoreReviewText,
                ),
              ],
              if (_isSupporter) ...[
                SizedBox(height: healthDp(context, 20)),
                _buildHelpCouponBanner(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader(BuildContext context) {
    final thumb = _productThumb;
    final name = (_review.itName ?? '').trim().isEmpty
        ? '상품'
        : _review.itName!.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: healthDp(context, 80),
          height: healthDp(context, 80),
          decoration: ShapeDecoration(
            color: const Color(0xFFF3F3F3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: thumb != null
              ? Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFFE0E0E0)),
                )
              : const ColoredBox(color: Color(0xFFE0E0E0)),
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '보미오라',
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 10),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: healthDp(context, 5)),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                  fontWeight: FontWeight.w700,
                  letterSpacing: healthSp(context, -1.26),
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              if (_writtenDate.isNotEmpty)
                Text(
                  _writtenDate,
                  style: TextStyle(
                    color: _muted2,
                    fontSize: healthSp(context, 10),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: healthDp(context, 82),
          child: Text(
            _scoreText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _pink,
              fontSize: healthSp(context, 50),
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 16)),
        Expanded(
          child: _review.isGeneralReview
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: AppStarRating(
                    rating: _displayScore,
                    starSize: healthDp(context, 20),
                    gap: healthDp(context, 2),
                  ),
                )
              : Column(
                  children: [
                    _statBar(context, '효과', _pct(_review.score1)),
                    SizedBox(height: healthDp(context, 8)),
                    _statBar(context, '가성비', _pct(_review.score2)),
                    SizedBox(height: healthDp(context, 8)),
                    _statBar(context, '맛/향', _pct(_review.score3)),
                    SizedBox(height: healthDp(context, 8)),
                    _statBar(context, '편리함', _pct(_review.score4)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _statBar(BuildContext context, String label, int percent) {
    return Row(
      children: [
        SizedBox(
          width: healthDp(context, 48),
          child: Text(
            label,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: healthDp(context, 6),
              backgroundColor: const Color(0xFFF6F6F6),
              color: _pink,
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Text(
          '$percent%',
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    final images = _reviewImages;
    final h = healthDp(context, 290);
    return Column(
      children: [
        SizedBox(
          height: h,
          width: double.infinity,
          child: PageView.builder(
            controller: _imageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _imagePage = i),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: h,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFFE0E0E0)),
                ),
              );
            },
          ),
        ),
        if (images.length > 1) ...[
          SizedBox(height: healthDp(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              final active = i == _imagePage;
              return Container(
                width: healthDp(context, 5),
                height: healthDp(context, 5),
                margin: EdgeInsets.symmetric(horizontal: healthDp(context, 2.5)),
                decoration: BoxDecoration(
                  color: active ? _pink : const Color(0xFFD2D2D2),
                  borderRadius: BorderRadius.circular(healthDp(context, 20)),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAuthorBlock(BuildContext context) {
    final name = (_review.isName ?? '').trim().isEmpty
        ? '회원'
        : _review.isName!.trim();
    final meta = <String>[];
    if (_review.isHeight != null && _review.isHeight! > 0) {
      meta.add('${_review.isHeight}cm');
    }
    if (_review.isOutageNum != null && _review.isOutageNum! > 0) {
      meta.add('${_review.isOutageNum}kg 감량');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isSupporter) ...[
              SizedBox(width: healthDp(context, 4)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 4),
                  vertical: healthDp(context, 2),
                ),
                decoration: ShapeDecoration(
                  color: _pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 100)),
                  ),
                ),
                child: Text(
                  '서포터 리뷰어',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 10),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (meta.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 4)),
          Text(
            meta.join('  '),
            style: TextStyle(
              color: _muted2,
              fontSize: healthSp(context, 10),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextSection(
    BuildContext context, {
    required String title,
    required String? body,
  }) {
    final text = (body ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ' $title',
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
            letterSpacing: healthSp(context, -0.7),
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 20),
            vertical: healthDp(context, 15),
          ),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _border),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: healthSp(context, -0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpCouponBanner(BuildContext context) {
    final downloadCount = _review.czDownload ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _downloadHelpCoupon,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 20),
            vertical: healthDp(context, 10),
          ),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _pink),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          AppAssets.myReviewCouponIcon,
                          width: healthDp(context, 20),
                          height: healthDp(context, 20),
                          colorFilter: const ColorFilter.mode(
                            _pink,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 5)),
                        Text(
                          '5% 할인 도움 쿠폰',
                          style: TextStyle(
                            color: _pink,
                            fontSize: healthSp(context, 12),
                            fontFamily: _font,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$downloadCount',
                            style: TextStyle(
                              color: _pink,
                              fontSize: healthSp(context, 10),
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '명이 받았어요!',
                            style: TextStyle(
                              color: _muted,
                              fontSize: healthSp(context, 10),
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text(
                      '유효기간 : 발급일로부터 7일',
                      style: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 8),
                        fontFamily: _font,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: healthDp(context, 40),
                height: healthDp(context, 40),
                decoration: ShapeDecoration(
                  color: const Color(0x19FF5A8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 50)),
                  ),
                ),
                alignment: Alignment.center,
                child: _isLoading
                    ? SizedBox(
                        width: healthDp(context, 18),
                        height: healthDp(context, 18),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _pink,
                        ),
                      )
                    : SvgPicture.asset(
                        AppAssets.myReviewCouponCardDownload,
                        width: healthDp(context, 20),
                        height: healthDp(context, 20),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadHelpCoupon() async {
    if (_review.isId == null) return;
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (!mounted) return;
        await showLoginRequiredDialog(
          context,
          message: '도움 쿠폰은 로그인 후 받을 수 있습니다.',
        );
        return;
      }

      final result = await CouponService.downloadHelpCoupon(
        mbId: user.id,
        itId: _review.itId,
        isId: _review.isId!,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        final count = result['downloadCount'];
        final parsed = count is int
            ? count
            : int.tryParse(count?.toString() ?? '') ??
                (_review.czDownload ?? 0);
        setState(() {
          _review = ReviewModel(
            isId: _review.isId,
            itId: _review.itId,
            itName: _review.itName,
            itKind: _review.itKind,
            productImage: _review.productImage,
            mbId: _review.mbId,
            isName: _review.isName,
            isTime: _review.isTime,
            isConfirm: _review.isConfirm,
            isScore1: _review.isScore1,
            isScore2: _review.isScore2,
            isScore3: _review.isScore3,
            isScore4: _review.isScore4,
            totalIsScore: _review.totalIsScore,
            averageScore: _review.averageScore,
            isRvkind: _review.isRvkind,
            isRecommend: _review.isRecommend,
            isGood: _review.isGood,
            czDownload: parsed,
            isPositiveReviewText: _review.isPositiveReviewText,
            isNegativeReviewText: _review.isNegativeReviewText,
            isMoreReviewText: _review.isMoreReviewText,
            images: _review.images,
            isHeight: _review.isHeight,
            isWeight: _review.isWeight,
            isPayMthod: _review.isPayMthod,
            isOutageNum: _review.isOutageNum,
            odId: _review.odId,
          );
        });
        AppToastOverlay.show(context, '도움 쿠폰이 발급되었습니다.');
      } else {
        final msg = result['message']?.toString() ?? '쿠폰 발급에 실패했습니다.';
        AppToastOverlay.show(context, msg);
      }
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(context, '쿠폰 발급 중 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
