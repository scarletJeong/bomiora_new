import 'dart:async';

import 'announcement_service.dart';
import 'event_service.dart';

/// 홈 배너·신상품이 끝난 뒤 공지/진행중 이벤트를 미리 받아 둔다.
class CommunityPrefetch {
  static void afterHomeContent() {
    unawaited(_run());
  }

  static Future<void> _run() async {
    try {
      await Future.wait([
        AnnouncementService.getAnnouncements(page: 1, size: 6),
        EventService.getActiveEvents(),
      ]);
    } catch (_) {}
  }
}
