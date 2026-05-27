import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'health_expanded_chart_layout.dart';

/// 웹 확대 팝업 고정 크기 (Figma)
const double kHealthWebExpandDialogWidth = 1300;
const double kHealthWebExpandDialogHeight = 634;

/// 건강 그래프 확대:
/// - 웹: 뒷배경 딤 처리 + 1300×634 다이얼로그 팝업
/// - 앱: 가로 전환 후 새 페이지 push (기존 동작)
Future<void> openHealthChartExpandPage({
  required BuildContext context,
  required WidgetBuilder chartBuilder,
  WidgetBuilder? periodSelectorBuilder,
  WidgetBuilder? legendBuilder,
  ValueChanged<VoidCallback>? onRegisterRefresh,
  VoidCallback? onDisposeRefresh,
}) async {
  if (kIsWeb) {
    await _openWebPopup(
      context: context,
      chartBuilder: chartBuilder,
      periodSelectorBuilder: periodSelectorBuilder,
      legendBuilder: legendBuilder,
      onRegisterRefresh: onRegisterRefresh,
      onDisposeRefresh: onDisposeRefresh,
    );
  } else {
    await _openAppLandscapePage(
      context: context,
      chartBuilder: chartBuilder,
      periodSelectorBuilder: periodSelectorBuilder,
      legendBuilder: legendBuilder,
      onRegisterRefresh: onRegisterRefresh,
      onDisposeRefresh: onDisposeRefresh,
    );
  }
}

double _expandLayoutWidth(BuildContext context) {
  if (kIsWeb) return kHealthWebExpandDialogWidth;
  return MediaQuery.sizeOf(context).width;
}

double _expandTextScale(double layoutWidth) {
  final scaled = layoutWidth / 375.0;
  return scaled.clamp(1.0, kHealthWebExpandDialogWidth / 375.0);
}

/// [StatefulBuilder] 안에서 [onRegisterRefresh]를 매 빌드마다 호출하면
/// 다이얼로그/라우트가 닫힌 뒤에도 이전 `setState`가 남아 웹에서
/// `Trying to render a disposed EngineFlutterView`가 날 수 있음 → **한 번만** 등록.
class _ExpandRegisterRefreshOnce extends StatefulWidget {
  const _ExpandRegisterRefreshOnce({
    required this.onRegisterRefresh,
    required this.builder,
  });

  final ValueChanged<VoidCallback>? onRegisterRefresh;
  final WidgetBuilder builder;

  @override
  State<_ExpandRegisterRefreshOnce> createState() =>
      _ExpandRegisterRefreshOnceState();
}

class _ExpandRegisterRefreshOnceState extends State<_ExpandRegisterRefreshOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onRegisterRefresh?.call(() {
        if (!mounted) return;
        setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _buildExpandedShell({
  required BuildContext context,
  required VoidCallback onClose,
  required WidgetBuilder chartBuilder,
  WidgetBuilder? periodSelectorBuilder,
  WidgetBuilder? legendBuilder,
}) {
  final outerWidth = _expandLayoutWidth(context);
  final metrics = healthExpandedChartMetrics(outerWidth);
  final topPad = metrics.d(28.18);
  final bottomPad = 0.0;
  final headerToChart = metrics.d(17.62);
  final legendGap = metrics.d(HealthExpandedChartMetrics.chartToLegendGap);
  final hPad = metrics.d(75.75);
  final chartTextScale = _expandTextScale(outerWidth);

  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      size: Size(outerWidth, kHealthWebExpandDialogHeight),
      textScaler: TextScaler.noScaling,
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (periodSelectorBuilder != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: periodSelectorBuilder(context),
                  ),
                )
              else
                const Spacer(),
              HealthExpandedShrinkButton(
                metrics: metrics,
                onPressed: onClose,
              ),
            ],
          ),
          SizedBox(height: headerToChart),
          Expanded(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(chartTextScale),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: chartBuilder(context),
              ),
            ),
          ),
          if (legendBuilder != null) ...[
            SizedBox(height: legendGap),
            legendBuilder(context),
          ],
        ],
      ),
    ),
  );
}

/// 웹 전용: 1300×634 팝업
Future<void> _openWebPopup({
  required BuildContext context,
  required WidgetBuilder chartBuilder,
  WidgetBuilder? periodSelectorBuilder,
  WidgetBuilder? legendBuilder,
  ValueChanged<VoidCallback>? onRegisterRefresh,
  VoidCallback? onDisposeRefresh,
}) async {
  try {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      barrierDismissible: true,
      builder: (dialogCtx) {
        return _ExpandRegisterRefreshOnce(
          onRegisterRefresh: onRegisterRefresh,
          builder: (innerCtx) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: kHealthWebExpandDialogWidth,
                height: kHealthWebExpandDialogHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _buildExpandedShell(
                  context: innerCtx,
                  onClose: () => Navigator.of(dialogCtx).pop(),
                  chartBuilder: chartBuilder,
                  periodSelectorBuilder: periodSelectorBuilder,
                  legendBuilder: legendBuilder,
                ),
              ),
            ),
          ),
        );
      },
    );
  } finally {
    onDisposeRefresh?.call();
  }
}

/// 앱 전용: 가로 강제 전환 후 새 페이지 push
Future<void> _openAppLandscapePage({
  required BuildContext context,
  required WidgetBuilder chartBuilder,
  WidgetBuilder? periodSelectorBuilder,
  WidgetBuilder? legendBuilder,
  ValueChanged<VoidCallback>? onRegisterRefresh,
  VoidCallback? onDisposeRefresh,
}) async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  try {
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pageCtx) {
          return _ExpandRegisterRefreshOnce(
            onRegisterRefresh: onRegisterRefresh,
            builder: (innerCtx) {
              final outerWidth = MediaQuery.sizeOf(innerCtx).width;
              final metrics = healthExpandedChartMetrics(outerWidth);
              final hPad = metrics.d(24);
              final topPad = metrics.d(16);
              final bottomPad = 0.0;
              final chartTextScale = _expandTextScale(outerWidth);

              return Scaffold(
                backgroundColor: Colors.white,
                body: SafeArea(
                  child: MediaQuery(
                    data: MediaQuery.of(innerCtx).copyWith(
                      textScaler: TextScaler.noScaling,
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (periodSelectorBuilder != null)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: periodSelectorBuilder(innerCtx),
                                  ),
                                )
                              else
                                const Spacer(),
                              HealthExpandedShrinkButton(
                                metrics: metrics,
                                onPressed: () => Navigator.pop(pageCtx),
                              ),
                            ],
                          ),
                          SizedBox(height: metrics.d(12)),
                          Expanded(
                            child: MediaQuery(
                              data: MediaQuery.of(innerCtx).copyWith(
                                textScaler: TextScaler.linear(chartTextScale),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: chartBuilder(innerCtx),
                              ),
                            ),
                          ),
                          if (legendBuilder != null) ...[
                            SizedBox(
                              height: metrics.d(
                                HealthExpandedChartMetrics.chartToLegendGap,
                              ),
                            ),
                            legendBuilder(innerCtx),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  } finally {
    onDisposeRefresh?.call();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

/// 확대 페이지에서 [HealthExpandedPeriodSelector]에 넘길 metrics.
HealthExpandedChartMetrics healthExpandedMetrics(BuildContext context) {
  return healthExpandedChartMetrics(_expandLayoutWidth(context));
}
