import 'package:flutter/material.dart';

import '../health_responsive_scale.dart';

class HealthEditBottomSheetItem<T> {
  final T data;
  final String timeText;
  final Widget trailing;

  const HealthEditBottomSheetItem({
    required this.data,
    required this.timeText,
    required this.trailing,
  });
}

Future<T?> showHealthEditBottomSheet<T>({
  required BuildContext context,
  required List<HealthEditBottomSheetItem<T>> items,
  String title = '수정할 시간 선택',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(healthDp(context, 40)),
      ),
    ),
    builder: (sheetContext) {
      final maxHeight = MediaQuery.of(sheetContext).size.height * 0.55;
      final textScale =
          healthTextScaleByWidth(MediaQuery.of(sheetContext).size.width);
      return MediaQuery(
        data: MediaQuery.of(sheetContext).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: maxHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(sheetContext, 16),
                healthDp(sheetContext, 12),
                healthDp(sheetContext, 16),
                healthDp(sheetContext, 12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(sheetContext, 4),
                      vertical: healthDp(sheetContext, 8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: healthSp(sheetContext, 18),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: healthDp(sheetContext, 24),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  SizedBox(height: healthDp(sheetContext, 8)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: healthDp(sheetContext, 8)),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(
                            healthDp(sheetContext, 10),
                          ),
                          onTap: () => Navigator.pop(sheetContext, item.data),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(healthDp(sheetContext, 10)),
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  healthDp(sheetContext, 10),
                                ),
                              ),
                              shadows: [
                                BoxShadow(
                                  color: const Color(0x19000000),
                                  blurRadius: healthDp(sheetContext, 4.17),
                                  offset: Offset.zero,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: healthDp(sheetContext, 24),
                                  height: healthDp(sheetContext, 24),
                                  child: Icon(
                                    Icons.access_time,
                                    size: healthDp(sheetContext, 20),
                                    color: const Color(0xFF707070),
                                  ),
                                ),
                                SizedBox(width: healthDp(sheetContext, 15)),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.timeText,
                                        textScaler: TextScaler.noScaling,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: healthSp(sheetContext, 16),
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          item.trailing,
                                          SizedBox(
                                              width:
                                                  healthDp(sheetContext, 10)),
                                          Icon(
                                            Icons.chevron_right,
                                            color: const Color(0xFF9CA3AF),
                                            size: healthDp(sheetContext, 16),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
