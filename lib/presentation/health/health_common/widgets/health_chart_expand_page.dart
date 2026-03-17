import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> openHealthChartExpandPage({
  required BuildContext context,
  required WidgetBuilder periodSelectorBuilder,
  required WidgetBuilder chartBuilder,
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
