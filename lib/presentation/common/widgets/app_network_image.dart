import 'package:flutter/material.dart';

/// 리스트/카드용 네트워크 이미지 — 표시 크기에 맞춰 디코드해 메모리·렌더 부하를 줄입니다.
class AppNetworkImage extends StatefulWidget {
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

  /// 로드 완료(또는 실패) 시 1회 호출. 스플래시 대기 등에 사용.
  final VoidCallback? onSettled;

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
    this.onSettled,
  });

  static bool _isFinitePositive(double? v) =>
      v != null && v.isFinite && v > 0;

  static int? cachePx(BuildContext context, double? logical) {
    if (!_isFinitePositive(logical)) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = logical! * dpr;
    if (!px.isFinite) return null;
    return px.round().clamp(64, 1200);
  }

  static double? resolveLogical(
    double? preferred,
    double? fallback,
    double screenFallback,
  ) {
    if (_isFinitePositive(preferred)) return preferred;
    if (_isFinitePositive(fallback)) return fallback;
    if (_isFinitePositive(screenFallback)) return screenFallback;
    return null;
  }

  /// [AppNetworkImage]와 동일한 ResizeImage 키로 프리캐시.
  static Future<void> precacheUrl(
    BuildContext context,
    String url, {
    double? decodeWidthLogical,
    double? decodeHeightLogical,
    double? width,
    double? height,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final screenW = MediaQuery.sizeOf(context).width;
    final logicalW = resolveLogical(
      decodeWidthLogical,
      width,
      screenW > 0 ? screenW / 2 : 180,
    );
    final logicalH = resolveLogical(decodeHeightLogical, height, 0);
    final cacheW = cachePx(context, logicalW);
    final cacheH = cachePx(context, logicalH);

    ImageProvider provider = NetworkImage(trimmed);
    if (cacheW != null || cacheH != null) {
      provider = ResizeImage(
        provider,
        width: cacheW,
        height: cacheH,
        allowUpscaling: false,
      );
    }

    try {
      await precacheImage(provider, context);
    } catch (e) {
      debugPrint('[AppNetworkImage] precache fail: $trimmed → $e');
    }
  }

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  bool _settled = false;

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _settled = false;
    }
  }

  void _markSettled() {
    if (_settled) return;
    _settled = true;
    widget.onSettled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final logicalW = AppNetworkImage.resolveLogical(
      widget.decodeWidthLogical,
      widget.width,
      screenW > 0 ? screenW / 2 : 180,
    );
    final logicalH = AppNetworkImage.resolveLogical(
      widget.decodeHeightLogical,
      widget.height,
      0,
    );
    final cacheW = AppNetworkImage.cachePx(context, logicalW);
    final cacheH = AppNetworkImage.cachePx(context, logicalH);

    return Image.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) {
        _markSettled();
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            const SizedBox.shrink();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          _markSettled();
        }
        if (widget.loadingBuilder != null) {
          return widget.loadingBuilder!(context, child, loadingProgress);
        }
        return child;
      },
    );
  }
}
