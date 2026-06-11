import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../services/auth_service.dart';

class RecentViewService {
  /// 상품 상세 진입 시 최근 본 상품 기록 (비로그인 시 무시)
  static Future<void> recordView(
    String itId, {
    required String productKind,
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.trim().isEmpty) return;
      if (itId.trim().isEmpty) return;

      await ApiClient.post(
        ApiEndpoints.recentViewRecord,
        {
          'mb_id': user.id,
          'it_id': itId.trim(),
          'it_kind': productKind.trim(),
        },
      );
    } catch (_) {
      // 최근 본 상품 기록 실패는 상세 화면 UX에 영향 없음
    }
  }

  /// 드로어·마이페이지 등에서 최근 본 상품 목록 조회
  static Future<List<Map<String, dynamic>>> getRecentList({
    int limit = 4,
  }) async {
    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.trim().isEmpty) return [];

      final mbId = Uri.encodeQueryComponent(user.id);
      final safeLimit = limit.clamp(1, 20);
      final response = await ApiClient.get(
        '${ApiEndpoints.recentViewList}?mb_id=$mbId&limit=$safeLimit',
      );

      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        return [];
      }

      final data = json.decode(response.body);
      if (data is! Map || data['success'] != true) return [];
      final rows = data['data'];
      if (rows is! List) return [];

      return rows
          .map((raw) {
            if (raw is! Map) return null;
            return NodeValueParser.normalizeMap(
              Map<String, dynamic>.from(raw),
            );
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
