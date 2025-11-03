/// 적립포인트 계산 및 표시를 위한 헬퍼 클래스
class PointHelper {
  /// 적립포인트 텍스트 생성
  /// 
  /// [pointType] - it_point_type (1: 고정 포인트, 2: 비율 포인트)
  /// [point] - it_point 값
  /// [usePoint] - cf_use_point (포인트 사용 가능 여부)
  /// [price] - 제품 가격 (포인트 계산용)
  /// 
  /// 반환: "결제금액의 X% 적립" 또는 "X점" 형식의 문자열
  static String? calculatePointText({
    required dynamic pointType,
    required dynamic point,
    required bool? usePoint,
    int? price,
  }) {
    // 포인트 기능이 비활성화되어 있으면 null 반환
    if (usePoint != true) {
      return null;
    }
    
    // point 값이 없으면 null 반환
    if (point == null) {
      return null;
    }
    
    final intPointType = _parseInt(pointType);
    final intPoint = _parseInt(point);
    
    if (intPoint == null || intPoint == 0) {
      return null;
    }
    
    // point_type이 2면 비율 방식: "결제금액의 X% 적립"
    if (intPointType == 2) {
      return '결제금액의 $intPoint% 적립';
    } 
    // 그 외의 경우 고정 포인트 방식: "X점"
    else {
      return '$intPoint점';
    }
  }
  
  /// 정수로 파싱하는 헬퍼 함수
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
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
