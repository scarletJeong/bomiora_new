import 'dart:async';

import 'announcement_service.dart';
import 'event_service.dart';

/// 스플래시에서 배너·신상품이 끝난 뒤 공지/진행중 이벤트를 미리 받아 둔다.
class CommunityPrefetch {
  static Future<void>? _inFlight;

  static void afterHomeContent() {
    unawaited(ensurePrefetched());
  }

  static Future<void> ensurePrefetched() {
    final pending = _inFlight;
    if (pending != null) return pending;

    final run = _run();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  static Future<void> _run() async {
    try {
      await Future.wait([
        // 홈 NoticeSection과 동일 키(page:1, size:3)
        AnnouncementService.getAnnouncements(page: 1, size: 3),
        EventService.getActiveEvents(),
      ]);
    } catch (_) {}
  }
}
