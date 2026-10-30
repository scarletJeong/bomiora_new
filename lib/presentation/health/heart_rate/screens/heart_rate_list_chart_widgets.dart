part of 'heart_rate_list_screen.dart';

/// 시간대별(일) 차트 탭 시 표시
class _DailyChartTooltip {
  final Offset chartLocal;

  /// true: 해당 시에 기록 2건 이상 → 일상/운동 구간을 한 카드에 표시
  final bool isHourBucket;
  final HeartRateRecord? record;
  final int? bucketHour;
  final List<HeartRateRecord>? hourRecords;

  _DailyChartTooltip._({
    required this.chartLocal,
    required this.isHourBucket,
    this.record,
    this.bucketHour,
    this.hourRecords,
  });

  factory _DailyChartTooltip.single({
    required Offset chartLocal,
    required HeartRateRecord record,
  }) {
    return _DailyChartTooltip._(
      chartLocal: chartLocal,
      isHourBucket: false,
      record: record,
    );
  }

  factory _DailyChartTooltip.hourBucket({
    required Offset chartLocal,
    required int bucketHour,
    required List<HeartRateRecord> records,
  }) {
    return _DailyChartTooltip._(
      chartLocal: chartLocal,
      isHourBucket: true,
      bucketHour: bucketHour,
      hourRecords: records,
    );
  }
}

class _HeartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool compact;

  const _HeartLegend({
    required this.color,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = compact ? healthDp(context, 8) : healthDp(context, 12);
    final gap = compact ? healthDp(context, 3) : healthDp(context, 5);
    final fontSize = compact ? healthSp(context, 9) : healthSp(context, 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeartDailyVisual {
  final bool isBar;
  final double xNorm;
  final int singleBpm;
  final int minBpm;
  final int maxBpm;
  final Color color;
  final HeartRateRecord? record;
  final int? bucketHour;

  _HeartDailyVisual.point(
    this.xNorm,
    this.singleBpm,
    this.color,
    this.record,
  )   : isBar = false,
        minBpm = singleBpm,
        maxBpm = singleBpm,
        bucketHour = null;

  _HeartDailyVisual.range(
    this.xNorm,
    this.minBpm,
    this.maxBpm,
    this.color,
    this.bucketHour,
  )   : isBar = true,
        singleBpm = minBpm,
        record = null;

  @override
  bool operator ==(Object other) {
    if (other is! _HeartDailyVisual) return false;
    return isBar == other.isBar &&
        xNorm == other.xNorm &&
        minBpm == other.minBpm &&
        maxBpm == other.maxBpm &&
        color == other.color &&
        bucketHour == other.bucketHour &&
        record?.id == other.record?.id;
  }

  @override
  int get hashCode =>
      Object.hash(isBar, xNorm, minBpm, maxBpm, color, bucketHour, record?.id);
}

class _HeartRateChartPainter extends CustomPainter {
  final List<_HeartDailyVisual> visuals;
  final double minValue;
  final double maxValue;
  final double topPlotPad;
  final double bottomPlotPad;

  /// 375 기준 1.0 — healthTextScaleByWidth 값을 넘긴다.
  final double scale;
  final double? xUnitReservedWidth;

  _HeartRateChartPainter({
    required this.visuals,
    required this.minValue,
    required this.maxValue,
    required this.topPlotPad,
    required this.bottomPlotPad,
    this.scale = 1.0,
    this.xUnitReservedWidth,
  });

  static const double _leftPad = ChartConstants.weightDailyChartInnerPadH;
  static double _rightPad([double? xUnitReservedWidth]) =>
      ChartConstants.weightDailyChartInnerPadH +
      (xUnitReservedWidth ?? ChartConstants.weightXAxisUnitReservedWidth);
  static const double _baseDotRadius = 4.0;
  static const double _baseBarWidth = 5.0;
  static const double _baseMinBarHeight = 5.0;
  static const double _hitSlop = 14.0;

  /// 탭 위치가 점/막대에 가까우면 인덱스, 아니면 null (위에서 그린 순서 우선)
  static int? hitTestVisual(
    Offset local,
    Size size,
    List<_HeartDailyVisual> visuals, {
    required double minValue,
    required double maxValue,
    required double topPlotPad,
    required double bottomPlotPad,
    double scale = 1.0,
    double? xUnitReservedWidth,
  }) {
    if (visuals.isEmpty) return null;
    final plotH = size.height - topPlotPad - bottomPlotPad;
    final plotW = size.width - _leftPad - _rightPad(xUnitReservedWidth);
    final rangeBpm = maxValue - minValue;
    if (rangeBpm <= 0 || plotW <= 0 || plotH <= 0) return null;

    final dotRadius = _baseDotRadius * scale;
    final barWidth = _baseBarWidth * scale;
    final minBarHeight = _baseMinBarHeight * scale;

    double toY(double bpm) {
      final n = (maxValue - bpm) / rangeBpm;
      return topPlotPad + plotH * n;
    }

    for (int i = visuals.length - 1; i >= 0; i--) {
      final v = visuals[i];
      final x = _leftPad + plotW * v.xNorm.clamp(0.0, 1.0);
      if (v.isBar) {
        var yHigh = toY(v.maxBpm.toDouble());
        var yLow = toY(v.minBpm.toDouble());
        if (yHigh > yLow) {
          final t = yHigh;
          yHigh = yLow;
          yLow = t;
        }
        var barH = yLow - yHigh;
        if (barH < minBarHeight) {
          final mid = (yHigh + yLow) / 2;
          yHigh = mid - minBarHeight / 2;
          barH = minBarHeight;
        }
        final rect = Rect.fromLTRB(
          x - barWidth / 2 - _hitSlop,
          yHigh - _hitSlop,
          x + barWidth / 2 + _hitSlop,
          yHigh + barH + _hitSlop,
        );
        if (rect.contains(local)) return i;
      } else {
        final y = toY(v.singleBpm.toDouble());
        if ((local - Offset(x, y)).distance <= dotRadius + _hitSlop) {
          return i;
        }
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

    const leftPad = _leftPad;
    final rightPad = _rightPad(xUnitReservedWidth);
    final topPad = topPlotPad;
    final botPad = bottomPlotPad;
    final plotH = size.height - topPad - botPad;
    final plotW = size.width - leftPad - rightPad;

    if (visuals.isEmpty) return;

    final rangeBpm = maxValue - minValue;
    if (rangeBpm <= 0) return;

    double toY(double bpm) {
      final n = (maxValue - bpm) / rangeBpm;
      return topPad + plotH * n;
    }

    final dotRadius = _baseDotRadius * scale;
    final barWidth = _baseBarWidth * scale;
    final minBarHeight = _baseMinBarHeight * scale;

    for (final v in visuals) {
      final x = leftPad + plotW * v.xNorm.clamp(0.0, 1.0);
      final fill = Paint()
        ..color = v.color
        ..style = PaintingStyle.fill;

      if (v.isBar) {
        var yHigh = toY(v.maxBpm.toDouble());
        var yLow = toY(v.minBpm.toDouble());
        if (yHigh > yLow) {
          final t = yHigh;
          yHigh = yLow;
          yLow = t;
        }
        var barH = yLow - yHigh;
        if (barH < minBarHeight) {
          final mid = (yHigh + yLow) / 2;
          yHigh = mid - minBarHeight / 2;
          barH = minBarHeight;
        }
        final barRect = Rect.fromLTWH(x - barWidth / 2, yHigh, barWidth, barH);
        final cornerR = math.min(barWidth / 2, barH / 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect,
            Radius.circular(cornerR),
          ),
          fill,
        );
      } else {
        canvas.drawCircle(
          Offset(x, toY(v.singleBpm.toDouble())),
          dotRadius,
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateChartPainter oldDelegate) {
    return !listEquals(oldDelegate.visuals, visuals) ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.topPlotPad != topPlotPad ||
        oldDelegate.bottomPlotPad != bottomPlotPad ||
        oldDelegate.scale != scale ||
        oldDelegate.xUnitReservedWidth != xUnitReservedWidth;
  }
}
