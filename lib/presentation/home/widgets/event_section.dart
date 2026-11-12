import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/logging/failure_log.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/event/event_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/event_service.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'home_section_widgets.dart';

class EventSection extends StatefulWidget {
  const EventSection({super.key});

  @override
  State<EventSection> createState() => _EventSectionState();
}

class _EventSectionState extends State<EventSection> {
  late final Future<List<EventModel>> _future = _load();

  String _eventDateText(EventModel item) {
    final created = DateDisplayFormatter.tryParseYmdFlexible(item.wrDatetime);
    if (created != null) {
      return DateDisplayFormatter.formatYmdDash(created);
    }
    return DateDisplayFormatter.formatYmdFromString(item.wrDatetime)
        .replaceAll('.', '-');
  }

  Future<List<EventModel>> _load() async {
    try {
      return await EventService.getActiveEvents();
    } catch (e) {
      final user = await AuthService.getUser();
      await FailureLog.record(
        code: 'home.event',
        mbId: user?.id ?? '',
        reason: e.toString(),
        detail: {'api': ApiEndpoints.getActiveEvents},
      );
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventModel>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <EventModel>[];
        final topItems = items.take(3).toList();

        return Container(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                HomeListSectionHeader(
                  title: 'Event',
                  onMoreTap: () => Navigator.pushNamed(context, '/event'),
                ),
                SizedBox(height: homeListSectionHeaderBodyGap(context)),
                if (snapshot.connectionState == ConnectionState.waiting)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 20)),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: const Color(0xFFFF5A8D), strokeWidth: 2),
                      ),
                    ),
                  )
                else if (topItems.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
                    child: Center(
                      child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CenteredEmptyState.assetIcon(
                          context,
                          AppAssets.emptyEventIcon,
                          slot: 28,
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Text(
                          '등록된 이벤트가 없습니다.',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < topItems.length; i++) ...[
                        ...homeListSectionRowLeadingSeparators(context, i),
                        HomeListSectionRow(
                          title: topItems[i].wrSubject,
                          date: _eventDateText(topItems[i]),
                          highlight: i == 0,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/event/${topItems[i].wrId}',
                          ),
                        ),
                      ],
                    ],
                  ),
                const HomeListSectionBottomSolidDivider(),
              ],
            ),
          ),
        );
      },
    );
  }
}
