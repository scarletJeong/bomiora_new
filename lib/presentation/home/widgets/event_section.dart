import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/event/event_model.dart';
import '../../../data/services/event_service.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'home_list_section_widgets.dart';

class EventSection extends StatelessWidget {
  const EventSection({super.key});

  String _eventDateText(EventModel item) {
    final created = DateDisplayFormatter.tryParseYmdFlexible(item.wrDatetime);
    if (created != null) {
      return DateDisplayFormatter.formatYmdDash(created);
    }
    return DateDisplayFormatter.formatYmdFromString(item.wrDatetime)
        .replaceAll('.', '-');
  }

  DateTime _eventSortKey(EventModel item) {
    final created = DateDisplayFormatter.tryParseYmdFlexible(item.wrDatetime);
    if (created != null) return created;
    return DateTime.fromMillisecondsSinceEpoch(item.wrId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventModel>>(
      future: EventService.getActiveEvents(),
      builder: (context, snapshot) {
        final items = List<EventModel>.from(
          snapshot.data ?? const <EventModel>[],
        )..sort((a, b) => _eventSortKey(b).compareTo(_eventSortKey(a)));
        final topItems = items.take(3).toList();

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: healthDp(context, 191)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 24),
              vertical: healthDp(context, 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                HomeListSectionHeader(
                  title: 'Event',
                  onMoreTap: () => Navigator.pushNamed(context, '/evnt'),
                ),
                SizedBox(height: homeListSectionHeaderBodyGap(context)),
                if (snapshot.connectionState == ConnectionState.waiting)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 20)),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (topItems.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
                    child: Text(
                      '등록된 이벤트가 없습니다.',
                      style: TextStyle(
                        color: const Color(0x665B3F43),
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w400,
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
                            '/evnt/${topItems[i].wrId}',
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
