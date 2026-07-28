import 'package:flutter/material.dart';

/// 리뷰 별점 공통 색 (노랑)
const Color kAppStarYellow = Color(0xFFFFCC00);

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
    return Icon(
      filled ? Icons.star_rounded : Icons.star_border_rounded,
      size: size,
      color: color,
    );
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
    final f = fill.clamp(0.0, 1.0);
    if (f <= 0) {
      return Icon(Icons.star_border_rounded, color: color, size: size);
    }
    if (f >= 1 - 1e-9) {
      return Icon(Icons.star_rounded, color: color, size: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.star_border_rounded, color: color, size: size),
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
                  child: Icon(Icons.star_rounded, color: color, size: size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = rating.clamp(0.0, 5.0);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = preciseFill
            ? fractionalStar(fill: value - i, size: starSize, color: color)
            : Icon(
                starIconFor(value, i),
                color: color,
                size: starSize,
              );
        if (gap <= 0 || i == 4) return star;
        return Padding(
          padding: EdgeInsets.only(right: gap),
          child: star,
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
                    Icon(
                      AppStarRating.starIconFor(rating, i),
                      color: color,
                      size: starSize,
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
