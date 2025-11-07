class ProductOption {
  final String id; // io_id
  final String productId; // it_id
  final String step; // 상위 옵션 (마지막 숫자 앞까지, io_id에서 추출)
  final int? months; // 개월수 (숫자 부분만, io_id에서 추출)
  final String subOption; // 하위 옵션 전체 텍스트 (마지막 숫자부터 끝까지)
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
    required this.subOption,
    required this.price,
    required this.stock,
    this.type,
  });
  
  factory ProductOption.fromJson(Map<String, dynamic> json) {
    final ioId = json['id']?.toString() ?? '';
    
    // io_id에서 상위 옵션, 하위 옵션, 개월수 추출 (항상 직접 파싱)
    final step = _extractStep(ioId);
    final subOption = _extractSubOption(ioId);
    final months = _extractMonths(ioId);
    
    return ProductOption(
      id: ioId,
      productId: json['productId']?.toString() ?? json['it_id']?.toString() ?? '',
      step: step, // 상위 옵션
      months: months, // 숫자만
      subOption: subOption, // 하위 옵션 전체 텍스트
      price: _parseInt(json['price'] ?? 0),
      stock: _parseInt(json['stock'] ?? 0),
      type: json['type']?.toString(),
    );
  }
  
  /// io_id에서 상위 옵션 추출 (마지막 숫자 앞까지)
  /// 예: "[01단계]소프트_Soft1개월" -> "[01단계]소프트_Soft"
  ///     "[03단계]하드_Hard2개월" -> "[03단계]하드_Hard"
  static String _extractStep(String ioId) {
    if (ioId.isEmpty) return '';
    // ']' 다음부터 마지막 숫자 앞까지 추출
    final closeBracketIndex = ioId.lastIndexOf(']');
    if (closeBracketIndex == -1) {
      // ']'가 없으면 마지막 숫자 앞까지
      return ioId.replaceAll(RegExp(r'\d+[^0-9]*$'), '');
    }
    
    // ']' 이후 부분
    final afterBracket = ioId.substring(closeBracketIndex + 1);
    // 마지막 숫자 시작 위치 찾기
    final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(afterBracket);
    if (lastNumberMatch != null) {
      // ']'까지 + 마지막 숫자 앞까지
      return ioId.substring(0, closeBracketIndex + 1) + 
             afterBracket.substring(0, lastNumberMatch.start);
    }
    
    return ioId;
  }
  
  /// io_id에서 하위 옵션 전체 텍스트 추출 (마지막 숫자부터 끝까지)
  /// 예: "[01단계]소프트_Soft1개월" -> "1개월"
  ///     "[03단계]하드_Hard2개월" -> "2개월"
  static String _extractSubOption(String ioId) {
    if (ioId.isEmpty) return '';
    // ']' 이후 부분에서 마지막 숫자부터 끝까지
    final closeBracketIndex = ioId.lastIndexOf(']');
    if (closeBracketIndex == -1) {
      // ']'가 없으면 마지막 숫자부터 끝까지
      final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(ioId);
      if (lastNumberMatch != null) {
        return ioId.substring(lastNumberMatch.start);
      }
      return '';
    }
    
    // ']' 이후 부분
    final afterBracket = ioId.substring(closeBracketIndex + 1);
    // 마지막 숫자 시작 위치 찾기
    final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(afterBracket);
    if (lastNumberMatch != null) {
      return afterBracket.substring(lastNumberMatch.start);
    }
    
    return afterBracket;
  }
  
  /// io_id에서 하위 옵션(개월수 포함) 추출
  /// 예: "[01단계]소프트_Soft1개월" -> 1 (숫자만)
  ///     "[03단계]하드_Hard2개월" -> 2 (숫자만)
  static int? _extractMonths(String ioId) {
    if (ioId.isEmpty) return null;
    // 마지막 숫자 부분 추출
    final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(ioId);
    if (lastNumberMatch != null) {
      final numberStr = lastNumberMatch.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(numberStr);
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
  
  /// 표시용 옵션 텍스트 생성 (상위옵션 / 하위옵션)
  String get displayText {
    if (subOption.isNotEmpty) {
      return '$step / $subOption';
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

