import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// 포인트 관련 공통 서비스
class PointService {
  /// 사용자의 현재 보유 포인트 조회
  /// bomiora_point 테이블에서 mb_id에 해당하는 가장 최근의 po_mb_point 값을 반환
  static Future<int?> getUserPoint(String userId) async {
    try {
      print('💎 포인트 조회 시작 - userId: $userId');
      
      final response = await ApiClient.get(ApiEndpoints.userPoint(userId));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final pointData = data['data'];
          // po_mb_point 값 추출
          final point = pointData['po_mb_point'] ?? pointData['point'];
          print('✅ 포인트 조회 완료: $point');
          return point is int ? point : (point != null ? int.tryParse(point.toString()) : null);
        } else if (data['point'] != null) {
          // 직접 point 필드가 있는 경우
          final point = data['point'];
          print('✅ 포인트 조회 완료: $point');
          return point is int ? point : (point != null ? int.tryParse(point.toString()) : null);
        }
      }
      
      print('⚠️ 포인트 조회 실패: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ 포인트 조회 오류: $e');
      return null;
    }
  }
  
  /// 포인트 포맷팅 (콤마 추가)
  static String formatPoint(int? point) {
    if (point == null) return '0';
    return point.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
