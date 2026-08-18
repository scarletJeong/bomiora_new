import '../../../core/utils/node_value_parser.dart';

class ProductOption {
  /// 그누보드/PHP `chr(30)` — io_id 축 값 구분자
  static const String axisDelimiter = '\u001e';

  final String id; // io_id (chr(30) 포함 원문 유지 — 장바구니/주문 전송용)
  final String productId; // it_id
  /// io_id를 chr(30)으로 나눈 축 값들. 예: ["초코", "1주 플랜"]
  final List<String> optionParts;
  final String step; // 상위 옵션 (parts[0] 또는 N개월 앞)
  final int? months; // 개월수 (`N개월`이 있을 때만)
  final String subOption; // 하위 옵션 (parts[1..] 또는 N개월부터)
  final int price;
  final int stock;
  final String? type;
  /// 0=선택옵션, 1=추가옵션(레거시), 2=종속1, 3=종속2
  final int ioType;

  String get optionName => step;
  int? get days => months;
  bool get isMain => ioType == 0;
  bool get isDep1 => ioType == 2;
  bool get isDep2 => ioType == 3;
  bool get isLegacySupply => ioType == 1;
  bool get isDependent => ioType == 2 || ioType == 3;

  /// chr(30)으로 저장된 다축 옵션인지
  bool get hasAxisDelimiter => id.contains(axisDelimiter);

  ProductOption({
    required this.id,
    required this.productId,
    required this.optionParts,
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
    // chr(30)은 반드시 유지. 다른 C0 제어문자만 제거.
    final ioId = _preserveIoId(rawIoId);

    final parsed = _parseIoId(ioId);
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
      optionParts: parsed.parts,
      step: parsed.step,
      months: parsed.months,
      subOption: parsed.subOption,
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

  static final RegExp _monthsBoundary = RegExp(r'(\d+)개월');

  /// PHP `explode(chr(30), $opt_id)` 와 동일
  static List<String> splitOptionValues(String ioId) {
    if (ioId.isEmpty) return const [];
    if (!ioId.contains(axisDelimiter)) {
      final one = _sanitizePart(ioId);
      return one.isEmpty ? const [] : [one];
    }
    return ioId
        .split(axisDelimiter)
        .map(_sanitizePart)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static ({
    List<String> parts,
    String step,
    String subOption,
    int? months,
  }) _parseIoId(String ioId) {
    if (ioId.isEmpty) {
      return (parts: const [], step: '', subOption: '', months: null);
    }

    // 1) chr(30) 축 분리 (일반·비대면 공통 다축 옵션)
    if (ioId.contains(axisDelimiter)) {
      final parts = splitOptionValues(ioId);
      final step = parts.isNotEmpty ? parts.first : '';
      final subOption =
          parts.length > 1 ? parts.skip(1).join(' > ') : '';
      int? months;
      for (final p in parts) {
        final m = _monthsBoundary.firstMatch(p);
        if (m != null) {
          months = int.tryParse(m.group(1)!);
          break;
        }
      }
      return (
        parts: parts,
        step: step,
        subOption: subOption,
        months: months,
      );
    }

    // 2) 비대면 레거시: `N개월` 경계
    final monthsMatch = _monthsBoundary.firstMatch(ioId);
    if (monthsMatch != null) {
      final step = _sanitizePart(ioId.substring(0, monthsMatch.start));
      final subOption = _sanitizePart(ioId.substring(monthsMatch.start));
      final months = int.tryParse(monthsMatch.group(1)!);
      final parts = <String>[
        if (step.isNotEmpty) step,
        if (subOption.isNotEmpty) subOption,
      ];
      return (
        parts: parts,
        step: step,
        subOption: subOption,
        months: months,
      );
    }

    // 3) 단일 옵션
    final step = _sanitizePart(ioId);
    return (
      parts: step.isEmpty ? const <String>[] : [step],
      step: step,
      subOption: '',
      months: null,
    );
  }

  /// io_id 원문 보존: chr(30)=\x1E 유지, 그 외 제어문자만 제거
  static String _preserveIoId(String value) {
    return value.replaceAll(RegExp(r'[\x00-\x1D\x1F\x7F]'), '');
  }

  /// 축 값 표시용 (제어문자 제거)
  static String _sanitizePart(String value) {
    return value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  /// 화면 표시: `단계 / 개월`
  String get displayText {
    if (optionParts.length >= 2) {
      return optionParts.join(' / ');
    }
    if (subOption.isNotEmpty) {
      return '$step / $subOption';
    }
    if (step.isNotEmpty) return step;
    return _sanitizePart(id.replaceAll(axisDelimiter, ' / '));
  }

  /// 2번째 축 값 (드롭다운 하위 항목)
  String get axisValue2 {
    if (optionParts.length >= 2) return optionParts[1];
    return subOption;
  }

  String get formattedPrice {
    return '${price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }
}
