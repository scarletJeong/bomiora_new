import 'package:flutter/material.dart';

/// 리스트/카드용 네트워크 이미지 — 표시 크기에 맞춰 디코드해 메모리·렌더 부하를 줄입니다.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  /// 논리 픽셀 기준 가로(없으면 [width] 또는 화면 절반)
  final double? decodeWidthLogical;

  /// 논리 픽셀 기준 세로(없으면 [height])
  final double? decodeHeightLogical;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.loadingBuilder,
    this.decodeWidthLogical,
    this.decodeHeightLogical,
  });

  bool _isFinitePositive(double? v) =>
      v != null && v.isFinite && v > 0;

  int? _cachePx(BuildContext context, double? logical) {
    if (!_isFinitePositive(logical)) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = logical! * dpr;
    if (!px.isFinite) return null;
    return px.round().clamp(64, 1200);
  }

  double? _resolveLogical(double? preferred, double? fallback, double screenFallback) {
    if (_isFinitePositive(preferred)) return preferred;
    if (_isFinitePositive(fallback)) return fallback;
    if (_isFinitePositive(screenFallback)) return screenFallback;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final logicalW = _resolveLogical(
      decodeWidthLogical,
      width,
      screenW > 0 ? screenW / 2 : 180,
    );
    final logicalH = _resolveLogical(decodeHeightLogical, height, 0);
    final cacheW = _cachePx(context, logicalW);
    // 한쪽만 있어도 디코드 제한이 됨. Infinity height 전달 방지.
    final cacheH = _cachePx(context, logicalH);

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      filterQuality: FilterQuality.low,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
