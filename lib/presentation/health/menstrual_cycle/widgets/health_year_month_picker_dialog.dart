import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../health_common/health_responsive_scale.dart';

const _kBorderGray = Color(0xFFD2D2D2);
const _kShadow = Color(0x24000000);

double _healthDialogMaxWidth(
  BuildContext context, {
  required double horizontalInsetTotal,
  double base = 375,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final maxW = (w - horizontalInsetTotal).clamp(0.0, double.infinity);
  return maxW.clamp(0.0, base * 1.15);
}

TextStyle _wheelRowStyle(BuildContext context, int dist) {
  final isCenter = dist == 0;
  final base = isCenter ? healthSp(context, 24) : healthSp(context, 18);
  final opacity = isCenter ? 1.0 : (dist == 1 ? 0.55 : 0.25);
  return TextStyle(
    fontSize: base,
    fontFamily: 'Gmarket Sans TTF',
    fontWeight: isCenter ? FontWeight.w500 : FontWeight.w400,
    color: Color.fromRGBO(26, 26, 26, opacity),
    height: 1.0,
    letterSpacing: -0.2,
  );
}

/// 년/월 스크롤 팝업 — 오늘 달 이후 선택 불가.
///
/// 반환값은 선택된 Year/Month의 1일(DateTime) (예: 2026-05-01).
Future<DateTime?> showHealthYearMonthPickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  final max = lastDate == null
      ? DateTime(now.year, now.month, 1)
      : DateTime(lastDate.year, lastDate.month, 1);
  final min = DateTime(firstDate.year, firstDate.month, 1);
  final init = DateTime(initialDate.year, initialDate.month, 1);
  final clamped = init.isAfter(max) ? max : (init.isBefore(min) ? min : init);

  return showDialog<DateTime?>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.25),
    builder: (_) => _HealthYearMonthPickerDialog(
      initial: clamped,
      min: min,
      max: max,
    ),
  );
}

class _HealthYearMonthPickerDialog extends StatefulWidget {
  const _HealthYearMonthPickerDialog({
    required this.initial,
    required this.min,
    required this.max,
  });

  final DateTime initial;
  final DateTime min;
  final DateTime max;

  @override
  State<_HealthYearMonthPickerDialog> createState() =>
      _HealthYearMonthPickerDialogState();
}

class _HealthYearMonthPickerDialogState
    extends State<_HealthYearMonthPickerDialog> {
  late int _year;
  late int _month;

  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;

  int _lastYearWheelTickMs = 0;
  int _lastMonthWheelTickMs = 0;
  static const int _wheelTickDebounceMs = 90;

  int get _minYear => widget.min.year;
  int get _maxYear => widget.max.year;
  int get _yearCount => (_maxYear - _minYear + 1).clamp(1, 9999);

  int _minMonthForYear(int y) => (y == _minYear) ? widget.min.month : 1;
  int _maxMonthForYear(int y) => (y == _maxYear) ? widget.max.month : 12;
  int _monthCountForYear(int y) =>
      (_maxMonthForYear(y) - _minMonthForYear(y) + 1).clamp(1, 12);

  void _clampSelectionToRange() {
    final y = _year.clamp(_minYear, _maxYear);
    final minM = _minMonthForYear(y);
    final maxM = _maxMonthForYear(y);
    final m = _month.clamp(minM, maxM);
    _year = y;
    _month = m;
  }

  int _yearIndex(int year) => (year - _minYear).clamp(0, _yearCount - 1);

  int _monthIndex(int year, int month) {
    final minM = _minMonthForYear(year);
    return (month - minM).clamp(0, _monthCountForYear(year) - 1);
  }

  void _changeYearBy(int delta) {
    final next = (_year + delta).clamp(_minYear, _maxYear);
    if (next == _year) return;
    setState(() {
      _year = next;
      _clampSelectionToRange();
    });
    if (_yearController.hasClients) {
      _yearController.jumpToItem(_yearIndex(_year));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_monthController.hasClients) {
        _monthController.jumpToItem(_monthIndex(_year, _month));
      }
    });
  }

  void _changeMonthBy(int delta) {
    final minM = _minMonthForYear(_year);
    final maxM = _maxMonthForYear(_year);
    final next = (_month + delta).clamp(minM, maxM);
    if (next == _month) return;
    setState(() => _month = next);
    if (_monthController.hasClients) {
      _monthController.jumpToItem(_monthIndex(_year, _month));
    }
  }

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
    _clampSelectionToRange();
    _yearController =
        FixedExtentScrollController(initialItem: _yearIndex(_year));
    _monthController =
        FixedExtentScrollController(initialItem: _monthIndex(_year, _month));
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogInsetH = healthDp(context, 16);
    final dialogInsetV = healthDp(context, 24);
    final wheelAreaH = healthDp(context, 200);
    final itemExtent = healthDp(context, 44);
    const wheelVisibleRows = 4;
    final cardPad = EdgeInsets.fromLTRB(
      healthDp(context, 13),
      healthDp(context, 18),
      healthDp(context, 13),
      healthDp(context, 18),
    );
    final cardRadius = healthDp(context, 16);
    final wheelBorderW = healthDp(context, 0.5);
    final yearColW = healthDp(context, 76);
    final wheelGapW = healthDp(context, 40);
    final monthHighlightW = yearColW + healthDp(context, 12);
    final wheelsStripW = yearColW + wheelGapW + monthHighlightW;
    final btnGap = healthDp(context, 10);
    final btnRowH = healthDp(context, 38);
    final btnRadius = healthDp(context, 10);
    final btnFontSize = healthSp(context, 16);
    final actionsTopGap = healthDp(context, 16);

    final cardW = _healthDialogMaxWidth(
      context,
      horizontalInsetTotal: dialogInsetH * 2,
    );

    final highlightBorder = BorderSide(color: _kBorderGray, width: wheelBorderW);
    final highlightH = itemExtent + healthDp(context, 10);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogInsetH,
        vertical: dialogInsetV,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardW),
        child: Container(
          padding: cardPad,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: [
              BoxShadow(
                color: _kShadow,
                blurRadius: healthDp(context, 16),
                offset: Offset(0, healthDp(context, 6)),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: wheelAreaH,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    IgnorePointer(
                      child: Center(
                        child: SizedBox(
                          height: highlightH,
                          width: wheelsStripW,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: yearColW,
                                height: highlightH,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    top: highlightBorder,
                                    bottom: highlightBorder,
                                  ),
                                ),
                              ),
                              SizedBox(width: wheelGapW),
                              Container(
                                width: monthHighlightW,
                                height: highlightH,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    top: highlightBorder,
                                    bottom: highlightBorder,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: yearColW,
                            height: itemExtent * wheelVisibleRows,
                            child: Listener(
                              onPointerSignal: (event) {
                                if (!kIsWeb || event is! PointerScrollEvent) {
                                  return;
                                }
                                final nowMs =
                                    DateTime.now().millisecondsSinceEpoch;
                                if (nowMs - _lastYearWheelTickMs <
                                    _wheelTickDebounceMs) {
                                  return;
                                }
                                _lastYearWheelTickMs = nowMs;
                                final delta =
                                    event.scrollDelta.dy > 0 ? 1 : -1;
                                _changeYearBy(delta);
                              },
                              child: ListWheelScrollView.useDelegate(
                                controller: _yearController,
                                itemExtent: itemExtent,
                                physics: kIsWeb
                                    ? const NeverScrollableScrollPhysics()
                                    : const FixedExtentScrollPhysics(),
                                perspective: 0.003,
                                diameterRatio: 1.6,
                                onSelectedItemChanged: (i) {
                                  final nextYear =
                                      (_minYear + i).clamp(_minYear, _maxYear);
                                  if (nextYear == _year) return;
                                  final beforeCount =
                                      _monthCountForYear(_year);
                                  setState(() {
                                    _year = nextYear;
                                    _clampSelectionToRange();
                                  });
                                  final afterCount = _monthCountForYear(_year);
                                  if (beforeCount != afterCount) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      if (_monthController.hasClients) {
                                        _monthController.jumpToItem(
                                          _monthIndex(_year, _month),
                                        );
                                      }
                                    });
                                  }
                                },
                                childDelegate:
                                    ListWheelChildBuilderDelegate(
                                  childCount: _yearCount,
                                  builder: (context, index) {
                                    final value = _minYear + index;
                                    final dist = (value - _year).abs();
                                    return Center(
                                      child: Text(
                                        value.toString(),
                                        style: _wheelRowStyle(context, dist),
                                        overflow: TextOverflow.clip,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: wheelGapW),
                          SizedBox(
                            width: yearColW,
                            height: itemExtent * wheelVisibleRows,
                            child: Listener(
                              onPointerSignal: (event) {
                                if (!kIsWeb || event is! PointerScrollEvent) {
                                  return;
                                }
                                final nowMs =
                                    DateTime.now().millisecondsSinceEpoch;
                                if (nowMs - _lastMonthWheelTickMs <
                                    _wheelTickDebounceMs) {
                                  return;
                                }
                                _lastMonthWheelTickMs = nowMs;
                                final delta =
                                    event.scrollDelta.dy > 0 ? 1 : -1;
                                _changeMonthBy(delta);
                              },
                              child: ListWheelScrollView.useDelegate(
                                controller: _monthController,
                                itemExtent: itemExtent,
                                physics: kIsWeb
                                    ? const NeverScrollableScrollPhysics()
                                    : const FixedExtentScrollPhysics(),
                                perspective: 0.003,
                                diameterRatio: 1.6,
                                onSelectedItemChanged: (i) {
                                  final minM = _minMonthForYear(_year);
                                  final nextMonth = (minM + i)
                                      .clamp(minM, _maxMonthForYear(_year));
                                  if (nextMonth == _month) return;
                                  setState(() => _month = nextMonth);
                                },
                                childDelegate:
                                    ListWheelChildBuilderDelegate(
                                  childCount: _monthCountForYear(_year),
                                  builder: (context, index) {
                                    final minM = _minMonthForYear(_year);
                                    final value = minM + index;
                                    final dist = (value - _month).abs();
                                    return Center(
                                      child: Text(
                                        '${value.toString().padLeft(2, '0')}월',
                                        style: _wheelRowStyle(context, dist),
                                        overflow: TextOverflow.clip,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: actionsTopGap),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: btnRowH,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kBorderGray,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: _kBorderGray,
                            width: wheelBorderW,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(btnRadius),
                          ),
                        ),
                        child: Text(
                          '닫기',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: const Color(0xFF898383),
                            fontSize: btnFontSize,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: btnGap),
                  Expanded(
                    child: SizedBox(
                      height: btnRowH,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context, DateTime(_year, _month, 1));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A8D),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(btnRadius),
                          ),
                        ),
                        child: Text(
                          '등록',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: btnFontSize,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

