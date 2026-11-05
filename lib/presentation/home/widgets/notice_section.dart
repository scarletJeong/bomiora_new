import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/logging/failure_log.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/announcement/announcement_model.dart';
import '../../../data/services/announcement_service.dart';
import '../../../data/services/auth_service.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'home_section_widgets.dart';

class NoticeSection extends StatefulWidget {
  const NoticeSection({super.key});

  @override
  State<NoticeSection> createState() => _NoticeSectionState();
}

class _NoticeSectionState extends State<NoticeSection> {
  late final Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final result = await AnnouncementService.getAnnouncements(page: 1, size: 3);
    if (result['success'] != true) {
      final user = await AuthService.getUser();
      await FailureLog.record(
        code: 'home.announcement',
        mbId: user?.id ?? '',
        reason: result['message']?.toString() ?? '공지사항 목록을 불러오지 못했습니다.',
        detail: {
          'page': 1,
          'size': 3,
          if (result['statusCode'] != null) 'statusCode': result['statusCode'],
        },
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final items =
            (snapshot.data?['items'] as List<AnnouncementModel>?) ?? const [];
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
                        child: CircularProgressIndicator(color: const Color(0xFFFF5A8D), strokeWidth: 2),
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
                    child: Center(
                      child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CenteredEmptyState.assetIcon(
                          context,
                          AppAssets.emptyNoticeIcon,
                          slot: 28,
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Text(
                          '등록된 공지사항이 없습니다.',
                          style: TextStyle(
                            color: const Color(0x665B3F43),
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
                const HomeListSectionBottomSolidDivider(),
              ],
            ),
          ),
        );
      },
    );
  }
}
