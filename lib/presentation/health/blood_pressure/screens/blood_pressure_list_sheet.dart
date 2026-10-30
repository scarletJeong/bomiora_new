part of 'blood_pressure_list_screen.dart';

extension _BloodPressureListSheet on _BloodPressureListScreenState {
  // 시간별 기록 선택 바텀시트
  void _showTimeSelectionBottomSheet(List<BloodPressureRecord> records) async {
    final items = records
        .map(
          (record) => HealthEditBottomSheetItem<BloodPressureRecord>(
            data: record,
            timeText: DateFormat('HH:mm').format(record.measuredAt),
            buildTrailing: (ctx) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    healthBloodPressureBadge(
                      ctx,
                      label: '수',
                      color: const Color(0xFF85B0FF),
                    ),
                    SizedBox(width: healthDp(ctx, 5)),
                    Text(
                      '${record.systolic}',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(ctx, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: healthDp(ctx, 10)),
                Row(
                  children: [
                    healthBloodPressureBadge(
                      ctx,
                      label: '이',
                      color: const Color(0xFFFFBC71),
                    ),
                    SizedBox(width: healthDp(ctx, 5)),
                    Text(
                      '${record.diastolic}',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(ctx, 16),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();

    final selected = await showHealthEditBottomSheet<BloodPressureRecord>(
      context: context,
      items: items,
    );

    if (selected == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BloodPressureInputScreen(record: selected),
      ),
    );
  }
}
