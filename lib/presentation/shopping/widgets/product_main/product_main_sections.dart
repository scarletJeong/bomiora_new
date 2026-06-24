import 'dart:math' show max;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import 'product_main_category_tap.dart';

const _sectionLineColor = Color(0xFFD9D9D9);

/// 원장 소개 이미지
/// - **웹**: `web/img/product_main_intro.png` → 요청 URL은 `{현재 문서 기준}/img/product_main_intro.png`
///   (`Image.asset`은 Flutter 웹에서 `assets/assets/img/...`로 이중 `assets`가 붙어 404가 나기 쉬움)
/// - **모바일/데스크톱 앱**: `pubspec` 에셋 `assets/img/product_main_intro.png`
Widget _productMainIntroPhoto({
  required BuildContext context,
  required double width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.bottomCenter,
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  Widget fallback() => Icon(
        Icons.person_outline,
        size: healthDp(context, 72),
        color: Colors.grey[400],
      );

  if (kIsWeb) {
    final src = Uri.base.resolve('img/product_main_intro.png').toString();
    return Image.network(
      src,
      width: width.isFinite ? width : null,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      errorBuilder: (_, __, ___) => fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: healthDp(context, 28),
            height: healthDp(context, 28),
            child: CircularProgressIndicator(
              strokeWidth: healthDp(context, 2),
            ),
          ),
        );
      },
    );
  }

  return Image.asset(
    AppAssets.productIntro,
    width: width.isFinite ? width : null,
    height: height,
    fit: fit,
    alignment: alignment,
    filterQuality: filterQuality,
    errorBuilder: (_, __, ___) => fallback(),
  );
}

/// 약력/대외활동 — 제목 줄(짧은 양쪽 선) 가운데 정렬, 본문 시작점 = 왼쪽 선 시작점
Widget _bioTitleWithLinesAndAlignedBody({
  required BuildContext context,
  required String title,
  required List<String> lines,
  required double maxWidth,
}) {
  final titleStyle = TextStyle(
    color: Colors.black,
    fontSize: healthSp(context, 12),
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w300,
  );
  final bodyStyle = TextStyle(
    color: Colors.black,
    fontSize: healthSp(context, 12),
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: FontWeight.w300,
    letterSpacing: -healthSp(context, 0.54),
  );
  final titleHPad = healthDp(context, 16);

  final tp = TextPainter(
    text: TextSpan(text: title, style: titleStyle),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  final titleW = tp.size.width;
  final fullW = maxWidth;
  // 제목·좌우 패딩을 뺀 나머지를 반반 — 살짝만 짧게(꽉 채우기보다 약간 여유)
  final halfSide = ((fullW - titleW - titleHPad * 2) / 2) * 0.72;
  final lineW = halfSide.clamp(0.0, fullW);
  final rowWidth = 2 * lineW + titleW + 2 * titleHPad;
  final leftInset = ((fullW - rowWidth) / 2).clamp(0.0, fullW);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: fullW,
        child: Align(
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: lineW,
                child: Divider(
                  height: healthDp(context, 1),
                  thickness: healthDp(context, 1),
                  color: _sectionLineColor,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: titleHPad),
                child: Text(title, style: titleStyle),
              ),
              SizedBox(
                width: lineW,
                child: Divider(
                  height: healthDp(context, 1),
                  thickness: healthDp(context, 1),
                  color: _sectionLineColor,
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: healthDp(context, 15)),
      Padding(
        padding: EdgeInsets.only(left: leftInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (t) => Padding(
                  padding: EdgeInsets.only(bottom: healthDp(context, 6)),
                  child: Text(
                    t,
                    textAlign: TextAlign.left,
                    style: bodyStyle,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 비대면 처방 메인 — 섹션 단위 (한 파일에서 관리)
// ---------------------------------------------------------------------------

/// 다이어트는 처음부터 ~ (히어로 이미지 + 인용 + 소개 + 핑크 문구)
class ProductMainQuoteSection extends StatelessWidget {
  const ProductMainQuoteSection({super.key});
  static const _blendBg = Color(0xFFF2ECEA);

  @override
  Widget build(BuildContext context) {
    final extend = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        return _ProductMainQuoteStack(
          width: constraints.maxWidth,
          extend: extend,
          blendBg: _blendBg,
        );
      },
    );
  }
}

/// 히어로 이미지는 `Positioned`라 레이아웃 높이에 안 잡힘 → 실제 이미지 높이만큼
/// 하단 여백을 두어 다음 섹션(Check Point)이 이미지 하단에서 이어지게 함.
class _ProductMainQuoteStack extends StatefulWidget {
  const _ProductMainQuoteStack({
    required this.width,
    required this.extend,
    required this.blendBg,
  });

  final double width;
  final double extend;
  final Color blendBg;

  @override
  State<_ProductMainQuoteStack> createState() => _ProductMainQuoteStackState();
}

class _ProductMainQuoteStackState extends State<_ProductMainQuoteStack> {
  /// 375 기준: 히어로 이미지를 위로 당기는 오프셋
  static const double _heroTopLiftBase = 0;

  /// 375 기준: 히어로 이미지를 아래로 내리는 여백
  static const double _heroImageTopInsetBase = 0;

  /// 375 기준: 이미지 상단 → 인용문 첫 줄 (화면 폭에 비례해 스케일)
  static const double _heroQuoteTextTopFromImageBase = 90;

  final GlobalKey _textColumnKey = GlobalKey();
  ImageStream? _imageStream;
  late final ImageStreamListener _imageListener;

  double? _heroDisplayHeight;
  double _sectionLayoutHeight = 0;

  @override
  void initState() {
    super.initState();
    _imageListener = ImageStreamListener(_onHeroImageLoaded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncSectionLayoutHeight();
    });
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_imageListener);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenHeroImage();
  }

  @override
  void didUpdateWidget(covariant _ProductMainQuoteStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) {
      _listenHeroImage();
      _scheduleSyncExtraBottom();
    }
  }

  void _listenHeroImage() {
    if (!mounted) return;
    final w = widget.width;
    if (!w.isFinite || w <= 0) return;

    const provider = AssetImage(AppAssets.productMain);
    final config = createLocalImageConfiguration(
      context,
      size: Size(w, 1),
    );
    final stream = provider.resolve(config);
    if (identical(stream, _imageStream)) return;
    _imageStream?.removeListener(_imageListener);
    _imageStream = stream;
    _imageStream!.addListener(_imageListener);
  }

  void _onHeroImageLoaded(ImageInfo info, bool synchronousCall) {
    if (!mounted) return;
    final iw = info.image.width.toDouble();
    final ih = info.image.height.toDouble();
    if (iw <= 0) return;
    final h = widget.width * ih / iw;
    if (_heroDisplayHeight == h) {
      _scheduleSyncExtraBottom();
      return;
    }
    setState(() => _heroDisplayHeight = h);
    _scheduleSyncExtraBottom();
  }

  void _scheduleSyncExtraBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncSectionLayoutHeight();
    });
  }

  double _heroImageTop(BuildContext context) {
    return -widget.extend -
        healthDp(context, _heroTopLiftBase) +
        healthDp(context, _heroImageTopInsetBase);
  }

  double _heroTextTop(BuildContext context) {
    return _heroImageTop(context) +
        healthDp(context, _heroQuoteTextTopFromImageBase);
  }

  void _syncSectionLayoutHeight() {
    if (!mounted || _heroDisplayHeight == null) return;
    final ctx = _textColumnKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _scheduleSyncExtraBottom();
      return;
    }
    final textH = box.size.height;
    final imageTop = _heroImageTop(context);
    final textTop = _heroTextTop(context);
    final heroBottom = imageTop + _heroDisplayHeight!;
    final textBottom = textTop + textH;
    final layoutHeight = max(heroBottom, textBottom);
    if ((layoutHeight - _sectionLayoutHeight).abs() > 0.5) {
      setState(() => _sectionLayoutHeight = layoutHeight);
    }
  }

  Widget _buildQuoteTextColumn(BuildContext context) {
    return Column(
      key: _textColumnKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '" 다이어트는 처음부터 쉬워야 합니다. " ',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -healthSp(context, 0.44),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: healthDp(context, 5)),
        Text(
          '정대진 │ 대표원장',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            letterSpacing: -healthSp(context, 0.54),
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        Text(
          '정대진 대표원장이 수년간 직접 몸을 관리하며',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            letterSpacing: -healthSp(context, 1.26),
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Text(
          '쌓은 다이어트 노하우와 다수의 임상례를 바탕으로',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            letterSpacing: -healthSp(context, 1.26),
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              letterSpacing: -healthSp(context, 1.26),
              color: Colors.black,
            ),
            children: [
              const TextSpan(text: '마침내 만들어진 '),
              TextSpan(
                text: '[보미 다이어트 솔루션]',
                style: TextStyle(
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -healthSp(context, 1.26),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: healthDp(context, 20)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '보미 다이어트 솔루션',
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  letterSpacing: -healthSp(context, 1.26),
                ),
              ),
              TextSpan(
                text: '으로',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -healthSp(context, 1.26),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          '당신의 아름다운 봄을',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -healthSp(context, 1.26),
          ),
        ),
        Text(
          '보미오라와 함께 만나보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -healthSp(context, 1.26),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final blendBg = widget.blendBg;
    final imageTop = _heroImageTop(context);
    final textTop = _heroTextTop(context);
    final hPad = healthDp(context, 20);
    final fallbackHeroH = w * 3454 / 2661;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: imageTop,
          child: SizedBox(
            width: w,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Image.asset(
                  AppAssets.productMain,
                  width: w,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) =>
                      ColoredBox(color: Colors.grey[200]!),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: const Alignment(0, 0.58),
                        colors: [
                          Colors.white.withValues(alpha: 1.0),
                          Colors.white.withValues(alpha: 1.0),
                          Colors.white.withValues(alpha: 0.62),
                          blendBg.withValues(alpha: 0.26),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.20, 0.34, 0.48, 0.58],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.03),
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.30),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: textTop,
          left: hPad,
          right: hPad,
          child: RepaintBoundary(child: _buildQuoteTextColumn(context)),
        ),
        SizedBox(
          height: _sectionLayoutHeight > 0
              ? _sectionLayoutHeight
              : imageTop +
                  (_heroDisplayHeight ?? fallbackHeroH) +
                  healthDp(context, _heroQuoteTextTopFromImageBase),
        ),
      ],
    );
  }
}

/// 보미 솔루션 Check Point (Point 1~3, 아이콘은 제목 위)
class ProductMainCheckpointSection extends StatelessWidget {
  const ProductMainCheckpointSection({super.key});

  @override
  Widget build(BuildContext context) {
    final pointLabelStyle = TextStyle(
      color: const Color(0xFF999999),
      fontSize: healthSp(context, 10),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
      letterSpacing: -healthSp(context, 0.50),
    );
    final titleStyle = TextStyle(
      color: Colors.black,
      fontSize: healthSp(context, 16),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
    );
    final bodyStyle = TextStyle(
      color: Colors.black,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '보미 솔루션 ',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 20),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -healthSp(context, 1),
                  ),
                ),
                TextSpan(
                  text: 'Check Point!',
                  style: TextStyle(
                    color: const Color(0xFFFF3787),
                    fontSize: healthSp(context, 20),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    letterSpacing: -healthSp(context, 1),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: healthDp(context, 28)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 20)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(healthDp(context, 16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: healthDp(context, 16),
                  offset: Offset(0, healthDp(context, 4)),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _pointColumn(
                  context: context,
                  pointLabelStyle: pointLabelStyle,
                  titleStyle: titleStyle,
                  bodyStyle: bodyStyle,
                  pointLabel: 'Point 1',
                  iconAsset: AppAssets.productMainIcon1,
                  title: '1:1 코칭',
                  bodies: const [
                    '다이어트는 개개인의 몸상태와 성격이',
                    '모두 다르기 때문에 1:1코칭이 꼭! 필요합니다.',
                  ],
                ),
                SizedBox(height: healthDp(context, 20)),
                Divider(
                  height: healthDp(context, 0.5),
                  thickness: healthDp(context, 0.5),
                  color: Colors.grey[300]!,
                ),
                SizedBox(height: healthDp(context, 20)),
                _pointColumn(
                  context: context,
                  pointLabelStyle: pointLabelStyle,
                  titleStyle: titleStyle,
                  bodyStyle: bodyStyle,
                  pointLabel: 'Point 2',
                  iconAsset: AppAssets.productMainIcon2,
                  title: '체지방 감소 및 독소 해소',
                  bodies: const [
                    '정대진 원장이 직접 개발한 다이어트 & 디톡스환은',
                    '체지방 감소 및 독소 배출에 도움을 줍니다.',
                  ],
                ),
                SizedBox(height: healthDp(context, 20)),
                Divider(
                  height: healthDp(context, 1),
                  thickness: healthDp(context, 1),
                  color: Colors.grey[300]!,
                ),
                SizedBox(height: healthDp(context, 20)),
                _pointColumn(
                  context: context,
                  pointLabelStyle: pointLabelStyle,
                  titleStyle: titleStyle,
                  bodyStyle: bodyStyle,
                  pointLabel: 'Point 3',
                  iconAsset: AppAssets.productMainIcon3,
                  title: '체질 개선',
                  bodies: const [
                    '개인의 체질을 본질적으로 개선해 주기 때문에',
                    '요요 없이 건강하게 다이어트를 할 수 있습니다.',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointColumn({
    required BuildContext context,
    required TextStyle pointLabelStyle,
    required TextStyle titleStyle,
    required TextStyle bodyStyle,
    required String pointLabel,
    required String iconAsset,
    required String title,
    required List<String> bodies,
  }) {
    final iconBox = healthDp(context, 40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(pointLabel, style: pointLabelStyle, textAlign: TextAlign.center),
        SizedBox(height: healthDp(context, 10)),
        SizedBox(
          width: iconBox,
          height: iconBox,
          child: SvgPicture.asset(iconAsset, fit: BoxFit.contain),
        ),
        SizedBox(height: healthDp(context, 10)),
        Text(title, style: titleStyle, textAlign: TextAlign.center),
        SizedBox(height: healthDp(context, 10)),
        ...bodies.map(
          (line) => Padding(
            padding: EdgeInsets.only(top: healthDp(context, 0)),
            child: Text(
              line,
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// 믿을 수 있는 든든한 ~ (분홍 구분선 + 카테고리 + 회색 구분선 + 카피)
class ProductMainTrustSection extends StatelessWidget {
  const ProductMainTrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: healthDp(context, 8)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
          child: Divider(
            height: healthDp(context, 1),
            thickness: healthDp(context, 1),
            color: const Color(0xFFFF5A8D),
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        const ProductMainCategoryTap(
          productKind: 'prescription',
          compact: true,
        ),
        SizedBox(height: healthDp(context, 28)),
        Text(
          '믿을 수 있는 든든한 주치의가',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 18),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '되어드리겠습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 18),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
      ],
    );
  }
}

/// 원장 사진 영역 + 약력 + 대외활동 + 하단 2×2 이미지
class ProductMainPhotoBioSection extends StatelessWidget {
  const ProductMainPhotoBioSection({super.key});

  @override
  Widget build(BuildContext context) {
    final photoOuter = healthDp(context, 248);
    final photoInner = healthDp(context, 228);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: photoOuter,
            child: Center(
              child: SizedBox(
                width: photoInner,
                height: photoInner,
                child: ClipOval(
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFFDDE5ED)),
                      _productMainIntroPhoto(
                        context: context,
                        width: photoInner,
                        height: photoInner,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '보미오라한의원│대표원장',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: healthDp(context, 30)),
          LayoutBuilder(
            builder: (context, constraints) {
              final blockW = constraints.maxWidth.clamp(
                healthDp(context, 280),
                healthDp(context, 380),
              );
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: blockW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bioTitleWithLinesAndAlignedBody(
                        context: context,
                        title: '약력',
                        lines: _cvLines,
                        maxWidth: blockW,
                      ),
                      SizedBox(height: healthDp(context, 20)),
                      _bioTitleWithLinesAndAlignedBody(
                        context: context,
                        title: '대외활동',
                        lines: _activityLines,
                        maxWidth: blockW,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: healthDp(context, 60)),
          const _StaggeredBottomGrid(),
          SizedBox(height: healthDp(context, 60)),
        ],
      ),
    );
  }

  static const _cvLines = [
    '· 서울대학교 보건대학원 최고위과정',
    '· 대한한의학회 정회원',
    '· 대한한방비만학회 정회원',
    '· 대한약침학회 정회원',
    '· 대한한방미용성형학회 정회원',
    '· 한의임상피부과학회 정회원',
    '· 척추신경추나학회 정회원',
    '· 대한미병의학회 정회원',
    '· 코로나19 한의진료센터 공로 표창장',
    '· 국민체육진흥공단 스포츠산업 명예 홍보대사',
    '· 대한민국 베스트브랜드 어워즈 [한방다이어트 부문] 대상',
    '· 대한민국 소비자 만족 브랜드 [한방다이어트 부문] 1위',
    '· 메디타임즈 100대 [한방다이어트 부문] 명의 선정',
  ];

  static const _activityLines = [
    '· 몸짱 한의사로 각종 방송 및 대회, 강연 활동 중',
    '· KBS, MBC, SBS, JTBC 등 다수 건강 프로그램',
    '· 한의학전문의 패널로 출연',
    ' - 기분좋은날 / 나는 몸신이다 / 모란봉클럽 등',
    '· 다수 연예인 및 모델 인플루언서 주치의 ',
    '· 피트니스 대회, 모델 대회 심사위원 활동',
    ' - 국내 피트니스 및 모델 대회 다수 수상',
  ];
}

class _StaggeredBottomGrid extends StatelessWidget {
  const _StaggeredBottomGrid();

  @override
  Widget build(BuildContext context) {
    // 기본 설계(375 기준) — 폭에 따라 healthDp로 스케일
    final colW = healthDp(context, 124);
    final gap = healthDp(context, 8);
    final cellH = healthDp(context, 158);
    final stagger = healthDp(context, 24);
    final rowGap = healthDp(context, 10);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final leftW = (w - gap) / 2;
        final scale = leftW / colW;
        final h = cellH * scale;
        final g = gap;
        final rg = rowGap * scale;
        final st = stagger * scale;

        Widget cell(String asset) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 8)),
            child: AspectRatio(
              aspectRatio: leftW / h,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: Colors.grey[200]!),
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  cell(AppAssets.productMainBottom1),
                  SizedBox(height: rg),
                  cell(AppAssets.productMainBottom3),
                ],
              ),
            ),
            SizedBox(width: g),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: st),
                child: Column(
                  children: [
                    cell(AppAssets.productMainBottom2),
                    SizedBox(height: rg),
                    cell(AppAssets.productMainBottom4),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
