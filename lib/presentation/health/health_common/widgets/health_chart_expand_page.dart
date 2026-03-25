import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 건강 그래프 전체화면: 진입 시 가로 고정, 종료 시 세로 복귀 ([SystemChrome]).
Future<void> openHealthChartExpandPage({
  required BuildContext context,
  required WidgetBuilder periodSelectorBuilder,
  required WidgetBuilder chartBuilder,
  /// 확대 화면에서 그래프 아래에 표시할 범례(페이지별 전체 범례)
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
        builder: (context) {
          return StatefulBuilder(
            builder: (context, expandedSetState) {
              onRegisterRefresh?.call(() => expandedSetState(() {}));
              final legend = legendBuilder;
              return Scaffold(
                backgroundColor: Colors.white,
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        periodSelectorBuilder(context),
                        const SizedBox(height: 10),
                        Expanded(child: chartBuilder(context)),
                        if (legend != null) ...[
                          const SizedBox(height: 4),
                          legend(context),
                        ],
                      ],
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
