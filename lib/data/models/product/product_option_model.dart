class ProductOption {
  final String id; // io_id
  final String productId; // it_id
  final String step; // 단계 (숫자 앞까지, io_id에서 추출)
  final int? months; // 개월수 (숫자 부분, io_id에서 추출)
  final int price; // 옵션 가격
  final int stock; // 재고
  final String? type; // 옵션 타입
  
  // 하위 호환성을 위한 getter
  String get optionName => step; // 단계와 동일
  int? get days => months; // 개월수와 동일 (하위 호환)
  
  ProductOption({
    required this.id,
    required this.productId,
    required this.step,
    this.months,
    required this.price,
    required this.stock,
    this.type,
  });
  
  factory ProductOption.fromJson(Map<String, dynamic> json) {
    final ioId = json['id']?.toString() ?? '';
    
    // io_id에서 단계와 개월수 추출 (항상 직접 파싱)
    final step = _extractStep(ioId);
    final months = _extractMonths(ioId);
    
    return ProductOption(
      id: ioId,
      productId: json['productId']?.toString() ?? json['it_id']?.toString() ?? '',
      step: step, // 항상 Flutter에서 직접 파싱
      months: months, // 항상 Flutter에서 직접 파싱
      price: _parseInt(json['price'] ?? 0),
      stock: _parseInt(json['stock'] ?? 0),
      type: json['type']?.toString(),
    );
  }
  
  /// io_id에서 단계 추출 (첫 번째 숫자 앞까지)
  /// 예: "디톡스 플러스1개월" -> "디톡스 플러스"
  ///     "디톡스2개월(-10%)" -> "디톡스"
  static String _extractStep(String ioId) {
    if (ioId.isEmpty) return '';
    // 첫 번째 숫자부터 끝까지 제거하여 숫자 앞까지의 문자열 추출
    return ioId.replaceAll(RegExp(r'\d+.*'), '');
  }
  
  /// io_id에서 개월수 추출 (첫 번째 숫자 부분만)
  /// 예: "디톡스 플러스1개월" -> 1
  ///     "디톡스2개월(-10%)" -> 2
  static int? _extractMonths(String ioId) {
    if (ioId.isEmpty) return null;
    // 첫 번째로 나오는 숫자 부분만 추출
    final match = RegExp(r'\d+').firstMatch(ioId);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }
  
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }
  
  /// 표시용 옵션 텍스트 생성
  String get displayText {
    if (months != null) {
      return '$step${months}개월';
    }
    return step;
  }
  
  /// 가격 포맷팅
  String get formattedPrice {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}

