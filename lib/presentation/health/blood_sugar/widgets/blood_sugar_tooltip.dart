import 'package:flutter/material.dart';

/// 일별 툴팁 시간 표기: `N시`
String bloodSugarFormatKoreanTime(DateTime dt) {
  return '${dt.hour}시';
}

/// `M.d`(예: 3.24) → `3월 24일`
String bloodSugarWeekSlotToKorean(String mDotD) {
  final parts = mDotD.split('.');
  if (parts.length == 2) {
    final m = int.tryParse(parts[0].trim());
    final d = int.tryParse(parts[1].trim());
    if (m != null && d != null) return '$m월 $d일';
  }
  return mDotD;
}

/// `3월` 등 + 연도 → `2025년 3월`
String bloodSugarMonthSlotToKorean(int year, String monthLabel) {
  final m = int.tryParse(monthLabel.replaceAll(RegExp(r'[^0-9]'), ''));
  if (m != null) return '$year년 $m월';
  return monthLabel;
}

class BloodSugarTooltip extends StatelessWidget {
  final Map<String, dynamic> data;
  final String selectedPeriod;
  final DateTime selectedDate;
  final Offset? tooltipPosition;
  final double chartWidth;
  final double chartHeight;

  const BloodSugarTooltip({
    super.key,
    required this.data,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.tooltipPosition,
    required this.chartWidth,
    required this.chartHeight,
  });

  TextStyle get _timeStyle => TextStyle(
        color: Colors.grey[700],
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  /// 체중 툴팁: 일·주는 회색, 월 첫 줄은 black87
  TextStyle get _headerStyle {
    if (selectedPeriod == '월') {
      return const TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );
    }
    return _timeStyle;
  }

  static const TextStyle _valueStyle = TextStyle(
    color: Colors.black87,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  String _headerLine(Map<String, dynamic> payload) {
    switch (selectedPeriod) {
      case '일':
        if (payload['hourSlotBar'] == true) {
          final hour = payload['hour'] as int?;
          if (hour != null) {
            return '$hour시';
          }
        }
        final record = payload['record'];
        if (record != null) {
          try {
            if (record.measuredAt is DateTime) {
              return bloodSugarFormatKoreanTime(record.measuredAt as DateTime);
            }
            final parsed = DateTime.tryParse(record.measuredAt.toString());
            if (parsed != null) {
              return bloodSugarFormatKoreanTime(parsed);
            }
          } catch (_) {}
        }
        return '';
      case '주':
        return bloodSugarWeekSlotToKorean(payload['date']?.toString() ?? '');
      case '월':
        final y =
            (payload['chartYear'] as int?) ?? selectedDate.year;
        return bloodSugarMonthSlotToKorean(
          y,
          payload['date']?.toString() ?? '',
        );
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tooltipPosition == null) return const SizedBox.shrink();

    if (data['bloodSugarOverlapCluster'] == true) {
      return _buildOverlapClusterTooltip();
    }

    final bloodSugar = data['bloodSugar'];
    if (data['hourSlotBar'] == true) {
      final minSugar = data['minBloodSugar'] as int?;
      final maxSugar = data['maxBloodSugar'] as int?;
      if (minSugar == null || maxSugar == null) return const SizedBox.shrink();
      final header = _headerLine(data);
      final body = minSugar == maxSugar ? '$minSugar' : '$minSugar ~ $maxSugar';
      return _positionedCard(
        minWidth: 120,
        estimatedHeight: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (header.isNotEmpty)
              Text(
                header,
                style: _headerStyle,
                textAlign: TextAlign.center,
              ),
            if (header.isNotEmpty) const SizedBox(height: 4),
            Text(
              body,
              style: _valueStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (bloodSugar == null) return const SizedBox.shrink();

    final header = _headerLine(data);
    final typeRaw = data['measurementType']?.toString() ?? '';
    final typeLine =
        typeRaw.isEmpty ? '기타' : typeRaw;
    final body = '$typeLine  $bloodSugar';

    return _positionedCard(
      minWidth: 90,
      estimatedHeight: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (header.isNotEmpty)
            Text(
              header,
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          if (header.isNotEmpty) const SizedBox(height: 4),
          Text(
            body,
            style: _valueStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverlapClusterTooltip() {
    final raw = data['overlapEntries'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final entries = raw.map((e) {
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).where((m) => m['bloodSugar'] != null).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    final header = _headerLine(data);

    return _positionedCard(
      minWidth: 130,
      estimatedHeight: 40.0 + entries.length * 26.0,
      maxWidth: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (header.isNotEmpty)
            Text(
              header,
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          if (header.isNotEmpty) const SizedBox(height: 4),
          ...entries.map((e) {
            final mRaw = e['measurementType']?.toString() ?? '';
            final label = mRaw.isEmpty ? '기타' : mRaw;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '$label  ${e['bloodSugar']}',
                style: _valueStyle,
                textAlign: TextAlign.center,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _positionedCard({
    required Widget child,
    required double estimatedHeight,
    double minWidth = 110,
    double? maxWidth,
  }) {
    double tooltipX = tooltipPosition!.dx;
    double tooltipY = tooltipPosition!.dy - 60;

    final clampW = maxWidth ?? minWidth;
    if (tooltipX < 0) tooltipX = 0;
    if (tooltipX > chartWidth - clampW) tooltipX = chartWidth - clampW;
    if (tooltipY < 0) tooltipY = tooltipPosition!.dy + 20;
    if (tooltipY > chartHeight - estimatedHeight) {
      tooltipY = chartHeight - estimatedHeight;
    }

    return Positioned(
      left: tooltipX,
      top: tooltipY,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth ?? 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
