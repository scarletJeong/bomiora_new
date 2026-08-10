import '../../../core/utils/node_value_parser.dart';

class ProductOption {
  final String id; // io_id
  final String productId; // it_id
  final String step; // 상위 옵션 (마지막 숫자 앞까지, io_id에서 추출)
  final int? months; // 개월수 (숫자 부분만, io_id에서 추출)
  final String subOption; // 하위 옵션 전체 텍스트 (마지막 숫자부터 끝까지)
  final int price; // 옵션 가격
  final int stock; // 재고
  final String? type; // 옵션 타입 (문자열 하위호환)
  /// 0=선택옵션, 1=추가옵션(레거시), 2=종속1, 3=종속2
  final int ioType;

  // 하위 호환성을 위한 getter
  String get optionName => step; // 단계와 동일
  int? get days => months; // 개월수와 동일 (하위 호환)
  bool get isMain => ioType == 0;
  bool get isDep1 => ioType == 2;
  bool get isDep2 => ioType == 3;
  bool get isLegacySupply => ioType == 1;
  bool get isDependent => ioType == 2 || ioType == 3;

  ProductOption({
    required this.id,
    required this.productId,
    required this.step,
    this.months,
    required this.subOption,
    required this.price,
    required this.stock,
    this.type,
    this.ioType = 0,
  });
  
  factory ProductOption.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    final rawIoId =
        NodeValueParser.asString(normalized['id']) ??
        NodeValueParser.asString(normalized['io_id']) ??
        '';
    final ioId = _sanitizeText(rawIoId);
    
    // io_id에서 상위 옵션, 하위 옵션, 개월수 추출 (항상 직접 파싱)
    final step = _extractStep(ioId);
    final subOption = _extractSubOption(ioId);
    final months = _extractMonths(ioId);
    final parsedIoType = _parseInt(
      normalized['io_type'] ??
          normalized['ioType'] ??
          normalized['type'] ??
          0,
    );

    return ProductOption(
      id: ioId,
      productId:
          NodeValueParser.asString(normalized['productId']) ??
          NodeValueParser.asString(normalized['it_id']) ??
          '',
      step: step, // 상위 옵션
      months: months, // 숫자만
      subOption: subOption, // 하위 옵션 전체 텍스트
      price: _parseInt(
        normalized['price'] ??
            normalized['io_price'] ??
            normalized['ioPrice'] ??
            0,
      ),
      stock: _parseInt(
        normalized['stock'] ??
            normalized['io_stock_qty'] ??
            0,
      ),
      type: NodeValueParser.asString(normalized['type']),
      ioType: parsedIoType.clamp(0, 3),
    );
  }
  
  /// `N개월` 경계를 우선 사용.
  /// 예: "[01단계]_디톡스_Detox2개월(-10%)" → 개월=2 (할인율 10이 아님)
  static final RegExp _monthsBoundary = RegExp(r'(\d+)개월');

  /// io_id에서 상위 옵션 추출 (`N개월` 앞까지)
  /// 예: "[01단계]소프트_Soft1개월" -> "[01단계]소프트_Soft"
  ///     "[01단계]_디톡스_Detox2개월(-10%)" -> "[01단계]_디톡스_Detox"
  static String _extractStep(String ioId) {
    if (ioId.isEmpty) return '';
    final monthsMatch = _monthsBoundary.firstMatch(ioId);
    if (monthsMatch != null) {
      return _sanitizeText(ioId.substring(0, monthsMatch.start));
    }
    // fallback: 마지막 숫자 앞까지
    final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(ioId);
    if (lastNumberMatch != null) {
      return _sanitizeText(ioId.substring(0, lastNumberMatch.start));
    }
    return _sanitizeText(ioId);
  }

  /// io_id에서 하위 옵션 전체 텍스트 추출 (`N개월`부터 끝까지)
  /// 예: "[01단계]소프트_Soft1개월" -> "1개월"
  ///     "[01단계]_디톡스_Detox2개월(-10%)" -> "2개월(-10%)"
  static String _extractSubOption(String ioId) {
    if (ioId.isEmpty) return '';
    final monthsMatch = _monthsBoundary.firstMatch(ioId);
    if (monthsMatch != null) {
      return _sanitizeText(ioId.substring(monthsMatch.start));
    }
    final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(ioId);
    if (lastNumberMatch != null) {
      return _sanitizeText(ioId.substring(lastNumberMatch.start));
    }
    return '';
  }

  /// io_id에서 개월수 추출 (`N개월`의 N)
  /// 예: "[01단계]소프트_Soft1개월" -> 1
  ///     "[01단계]_디톡스_Detox2개월(-10%)" -> 2  (할인율 10 아님)
  static int? _extractMonths(String ioId) {
    if (ioId.isEmpty) return null;
    final monthsMatch = _monthsBoundary.firstMatch(ioId);
    if (monthsMatch != null) {
      return int.tryParse(monthsMatch.group(1)!);
    }
    final lastNumberMatch = RegExp(r'\d+[^0-9]*$').firstMatch(ioId);
    if (lastNumberMatch != null) {
      final numberStr =
          lastNumberMatch.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
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

  static String _sanitizeText(String value) {
    return value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
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

