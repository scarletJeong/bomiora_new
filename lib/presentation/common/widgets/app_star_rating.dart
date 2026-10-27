import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 리뷰 별점 공통 색 (노랑)
const Color kAppStarYellow = Color(0xFFFFDA00);

enum AppStarSnapMode {
  /// 0.5 단위
  half,
  /// 0.1 단위 (드래그·부분 채움)
  tenth,
}

double appStarSnapHalf(double raw) {
  if (raw <= 0) return 0.0;
  final c = raw.clamp(0.5, 5.0);
  return (c * 2).round() / 2.0;
}

double appStarSnapTenth(double raw) {
  if (raw <= 0) return 0.0;
  final c = raw.clamp(0.1, 5.0);
  return (c * 10).round() / 10.0;
}

/// 둥근 별 아이콘 1개 (`Icons.star_rounded` 계열)
class AppStarIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const AppStarIcon({
    super.key,
    this.size = 14,
    this.color = kAppStarYellow,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return _AppStarGlyph(size: size, color: color, fill: filled ? 1 : 0);
  }
}

/// 채움 0~1. 빈 부분은 얇은 테두리만 그린다.
class _AppStarGlyph extends StatelessWidget {
  final double size;
  final Color color;
  final double fill;

  const _AppStarGlyph({
    required this.size,
    required this.color,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ThinStarPainter(color: color, fill: fill.clamp(0.0, 1.0)),
    );
  }
}

class _ThinStarPainter extends CustomPainter {
  final Color color;
  final double fill;

  const _ThinStarPainter({required this.color, required this.fill});

  static Path _starPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.shortestSide / 2;
    final inner = outer * 0.42;
    final points = List<Offset>.generate(10, (i) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      return Offset(
        cx + radius * math.cos(angle),
        cy + radius * math.sin(angle),
      );
    });
    final corner = size.shortestSide * 0.16;
    final path = Path();
    final count = points.length;
    for (var i = 0; i < count; i++) {
      final curr = points[i];
      final prev = points[(i - 1 + count) % count];
      final next = points[(i + 1) % count];
      final toPrev = prev - curr;
      final toNext = next - curr;
      final lenPrev = toPrev.distance;
      final lenNext = toNext.distance;
      final cut = math.min(corner, math.min(lenPrev, lenNext) * 0.45);
      final start = curr + toPrev / lenPrev * cut;
      final end = curr + toNext / lenNext * cut;
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.shortestSide * 0.045).clamp(0.7, 1.15);
    final inset = stroke / 2;
    final path = _starPath(Size(size.width - stroke, size.height - stroke));
    canvas.save();
    canvas.translate(inset, inset);
    if (fill >= 1 - 1e-9) {
      canvas.drawPath(path, Paint()..color = color);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      if (fill > 0) {
        final innerW = size.width - stroke;
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, innerW * fill, size.height));
        canvas.drawPath(path, Paint()..color = color);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThinStarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.fill != fill;
  }
}

/// 0~5점 표시용 별 5개 (둥근 별 + 반별/부분 채움)
class AppStarRating extends StatelessWidget {
  final double rating;
  final double starSize;
  final double gap;
  final Color color;
  final MainAxisAlignment alignment;

  /// true면 0.1 단위 부분 채움, false면 반별(0.5) 아이콘
  final bool preciseFill;

  const AppStarRating({
    super.key,
    required this.rating,
    this.starSize = 14,
    this.gap = 0,
    this.color = kAppStarYellow,
    this.alignment = MainAxisAlignment.start,
    this.preciseFill = false,
  });

  static IconData starIconFor(double value, int index) {
    final full = index + 1.0;
    final half = index + 0.5;
    if (value >= full - 1e-9) return Icons.star_rounded;
    if (value >= half - 1e-9) return Icons.star_half_rounded;
    return Icons.star_border_rounded;
  }

  static Widget fractionalStar({
    required double fill,
    required double size,
    Color color = kAppStarYellow,
  }) {
    return _AppStarGlyph(size: size, color: color, fill: fill);
  }

  @override
  Widget build(BuildContext context) {
    final value = rating.clamp(0.0, 5.0);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = preciseFill
            ? fractionalStar(fill: value - i, size: starSize, color: color)
            : _AppStarGlyph(
                size: starSize,
                color: color,
                fill: value >= i + 1 - 1e-9
                    ? 1
                    : value >= i + 0.5 - 1e-9
                        ? 0.5
                        : 0,
              );
        if (i == 4 || gap == 0) return star;
        if (gap > 0) {
          return Padding(
            padding: EdgeInsets.only(right: gap),
            child: star,
          );
        }
        return SizedBox(
          width: math.max(0, starSize + gap),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: starSize,
            maxWidth: starSize,
            minHeight: starSize,
            maxHeight: starSize,
            child: star,
          ),
        );
      }),
    );

    // width: infinity 금지 — FittedBox/Stack 안에서 레이아웃 깨짐
    if (alignment == MainAxisAlignment.center) {
      return Center(child: row);
    }
    return row;
  }
}

/// 탭·드래그로 별점 입력 (`review_write_screen` 동작 이식)
class AppInteractiveStarRating extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final double starSize;
  final double gap;
  final Color color;
  final MainAxisAlignment alignment;
  final AppStarSnapMode snapMode;

  const AppInteractiveStarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.starSize = 24,
    this.gap = 4,
    this.color = kAppStarYellow,
    this.alignment = MainAxisAlignment.start,
    this.snapMode = AppStarSnapMode.tenth,
  });

  double _snap(double raw) {
    return snapMode == AppStarSnapMode.tenth
        ? appStarSnapTenth(raw)
        : appStarSnapHalf(raw);
  }

  @override
  Widget build(BuildContext context) {
    const tapRadius = Radius.circular(4);
    final rowWidth = starSize * 5 + gap * 4;
    final useTenth = snapMode == AppStarSnapMode.tenth;

    void applyLocalDx(double dx) {
      final t = (dx / rowWidth).clamp(0.0, 1.0);
      final raw = t * 5.0;
      if (raw <= 0) {
        onRatingChanged(0);
        return;
      }
      onRatingChanged(_snap(raw));
    }

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = useTenth
            ? AppStarRating.fractionalStar(
                fill: rating - i,
                size: starSize,
                color: color,
              )
            : SizedBox(
                width: starSize,
                height: starSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _AppStarGlyph(
                      size: starSize,
                      color: color,
                      fill: rating >= i + 1 - 1e-9
                          ? 1
                          : rating >= i + 0.5 - 1e-9
                              ? 0.5
                              : 0,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                onRatingChanged(appStarSnapHalf(i + 0.5)),
                            borderRadius:
                                BorderRadius.horizontal(left: tapRadius),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                onRatingChanged(appStarSnapHalf(i + 1.0)),
                            borderRadius:
                                BorderRadius.horizontal(right: tapRadius),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

        if (i == 4) return star;
        return Padding(
          padding: EdgeInsets.only(right: gap),
          child: star,
        );
      }),
    );

    final interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => applyLocalDx(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => applyLocalDx(d.localPosition.dx),
      child: SizedBox(
        width: rowWidth,
        height: starSize,
        child: stars,
      ),
    );

    // width: infinity 금지 — Stack 안에서 hasSize / hitTest 오류 유발
    if (alignment == MainAxisAlignment.center) {
      return Center(child: interactive);
    }
    return interactive;
  }
}
