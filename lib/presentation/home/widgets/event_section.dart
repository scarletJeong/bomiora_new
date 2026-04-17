import 'package:flutter/material.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/event/event_model.dart';
import '../../../data/services/event_service.dart';

class EventSection extends StatelessWidget {
  const EventSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventModel>>(
      future: EventService.getActiveEvents(),
      builder: (context, snapshot) {
        final items = List<EventModel>.from(snapshot.data ?? const <EventModel>[])
          ..sort((a, b) => _eventSortKey(b).compareTo(_eventSortKey(a)));
        final topItems = items.take(2).toList();
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 191),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 1,
                color: Color(0x26E4BDC2),
              ),
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 33),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 2,
                      height: 28,
                      color: const Color(0xFF28171A),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '이벤트',
                      style: TextStyle(
                        color: Color(0xFF28171A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: () => Navigator.pushNamed(context, '/evnt'),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFFF5A8D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        child: const Text(
                          '+ More',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (topItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '등록된 이벤트가 없습니다.',
                      style: TextStyle(
                        color: Color(0x665B3F43),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                else
                  ...topItems.map(
                    (item) => _NoticeRow(
                      title: item.wrSubject,
                      date: _eventDateText(item),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/evnt/${item.wrId}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _eventDateText(EventModel item) {
    final created = DateDisplayFormatter.tryParseYmdFlexible(item.wrDatetime);
    if (created != null) {
      return DateDisplayFormatter.formatYmd(created);
    }
    return DateDisplayFormatter.formatYmdFromString(item.wrDatetime);
  }

  DateTime _eventSortKey(EventModel item) {
    final created = DateDisplayFormatter.tryParseYmdFlexible(item.wrDatetime);
    if (created != null) return created;
    return DateTime.fromMillisecondsSinceEpoch(item.wrId);
  }
}

class _NoticeRow extends StatelessWidget {
  final String title;
  final String date;
  final VoidCallback? onTap;

  const _NoticeRow({
    required this.title,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: Color(0x19E4BDC2),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF28171A),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.33,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              date,
              style: const TextStyle(
                color: Color(0x665B3F43),
                fontSize: 10,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
