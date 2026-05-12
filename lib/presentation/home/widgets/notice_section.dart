import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/announcement/announcement_model.dart';
import '../../../data/services/announcement_service.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'home_section_widgets.dart';

class NoticeSection extends StatelessWidget {
  const NoticeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AnnouncementService.getAnnouncements(page: 1, size: 3),
      builder: (context, snapshot) {
        final items =
            (snapshot.data?['items'] as List<AnnouncementModel>?) ?? const [];
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
                  title: '공지사항',
                  onMoreTap: () =>
                      Navigator.pushNamed(context, '/announcement'),
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
                else if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
                    child: Text(
                      '등록된 공지사항이 없습니다.',
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
                      for (var i = 0; i < items.length; i++) ...[
                        ...homeListSectionRowLeadingSeparators(context, i),
                        HomeListSectionRow(
                          title: items[i].title,
                          date: items[i].createdAt == null
                              ? '-'
                              : DateDisplayFormatter.formatYmdDash(
                                  items[i].createdAt!,
                                ),
                          highlight: i == 0,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/announcement/${items[i].id}',
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
