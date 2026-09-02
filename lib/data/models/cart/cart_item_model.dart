import 'dart:convert';
import '../../../core/utils/node_value_parser.dart';

class CartItem {
  final int ctId; // 장바구니 ID
  final String odId; // 주문 ID
  final String mbId; // 회원 ID
  final String itId; // 상품 ID
  final String itName; // 상품명
  final String? itSubject; // 상품 설명
  final String ctStatus; // 장바구니 상태 (쇼핑, 주문완료 등)
  final int ctPrice; // 장바구니 가격 (총 가격)
  final String ctOption; // 옵션 정보
  final int ctQty; // 수량
  final String? ioId; // 옵션 ID
  final int? ioPrice; // 옵션 가격
  final int ioType; // 0~3
  final String ctKind; // 상품 종류 (general | prescription)
  /// 파싱된 kind: general | prescription | supply_add(parent 있을 때)
  final String kind;
  /// 상품 마스터 `item_new.it_kind` (prescription | general …)
  final String? itKind;
  final String? parentItId;
  /// 부모 상품의 it_supply_items (그룹핑 fallback)
  final String? itSupplyItems;
  final DateTime? ctTime; // 장바구니 추가 시간

  // 처방 상품인 경우 예약 정보
  final String? doctorName; // 담당 한의사 이름
  final DateTime? reservationDate; // 예약 일자
  final String? reservationTime; // 예약 시간 (예: "18:30 ~ 19:00")

  // 상품 이미지 URL
  final String? imageUrl;

  // 상품 타입 (한의약품 등)
  final String? productType;
  // 인플루언서 상품 구분값 (빈값이면 일반 상품)
  final String ctMbInf;
  // 포인트 사용 가능 비율 (0~100)
  final int pointUsageRate;
  /// 결제 대상 선택 여부 (`bomiora_shop_cart.ct_select`)
  final bool ctSelect;
  /// 품절·판매중지 여부 (서버 `is_available`)
  final bool isAvailable;
  final String? unavailableReason;

  CartItem({
    required this.ctId,
    required this.odId,
    required this.mbId,
    required this.itId,
    required this.itName,
    this.itSubject,
    required this.ctStatus,
    required this.ctPrice,
    this.ctOption = '',
    required this.ctQty,
    this.ioId,
    this.ioPrice,
    this.ioType = 0,
    required this.ctKind,
    this.kind = 'general',
    this.itKind,
    this.parentItId,
    this.itSupplyItems,
    this.ctTime,
    this.doctorName,
    this.reservationDate,
    this.reservationTime,
    this.imageUrl,
    this.productType,
    this.ctMbInf = '',
    this.pointUsageRate = 10,
    this.ctSelect = false,
    this.isAvailable = true,
    this.unavailableReason,
  });

  /// 추가상품: `parent` 컬럼(또는 legacy ct_kind=supply_add|)에 부모 it_id가 있음.
  /// `ct_kind=general` 본품은 DB에 parent가 잘못 붙어도 일반 라인으로 취급.
  bool get isSupplyAdd {
    if (_normalizeKind(ctKind) == 'general') return false;

    final p = parentItId?.trim() ?? '';
    if (p.isNotEmpty) return true;
    return kind == 'supply_add' || ctKind.startsWith('supply_add|');
  }

  /// 라인 결제금액 (io_type 1~3은 io_price 반영)
  int get lineAmount {
    final io = ioPrice ?? 0;
    if (ioType == 1 || ioType == 2 || ioType == 3) {
      return ctPrice + io * ctQty;
    }
    return ctPrice;
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    // ct_option에서 예약 정보 파싱 (예: JSON 문자열 또는 특정 형식)
    String? doctorName;
    DateTime? reservationDate;
    String? reservationTime;

    if (normalized['ct_option'] != null &&
        NodeValueParser.asString(normalized['ct_option'])!.isNotEmpty) {
      try {
        final ctOptionStr = NodeValueParser.asString(normalized['ct_option'])!;

        // JSON 문자열인지 확인 (시작이 '{' 또는 '['로 시작하는 경우만 JSON으로 처리)
        if (ctOptionStr.trim().startsWith('{') ||
            ctOptionStr.trim().startsWith('[')) {
          // ct_option이 JSON 문자열인 경우
          final optionData = jsonDecode(ctOptionStr);

          if (optionData is Map) {
            doctorName = optionData['doctor_name']?.toString() ??
                optionData['doctorName']?.toString();
            if (optionData['reservation_date'] != null ||
                optionData['reservationDate'] != null) {
              final dateStr = optionData['reservation_date']?.toString() ??
                  optionData['reservationDate']?.toString();
              if (dateStr != null && dateStr.isNotEmpty) {
                reservationDate = DateTime.tryParse(dateStr);
              }
            }
            reservationTime = optionData['reservation_time']?.toString() ??
                optionData['reservationTime']?.toString();
          }
        }
        // JSON이 아닌 경우 (예: "소프트 / 3일(6포)")는 그냥 옵션 텍스트로 처리
      } catch (e) {
        // JSON 파싱 실패 시 무시 (일반 텍스트일 수 있음)
        // 일반 텍스트 옵션은 정상이므로 에러 로그 제거
      }
    }

    // ct_time 파싱
    DateTime? ctTime;
    if (normalized['ct_time'] != null) {
      final timeStr = NodeValueParser.asString(normalized['ct_time']) ?? '';
      if (timeStr.isNotEmpty && timeStr != '0000-00-00 00:00:00') {
        ctTime = DateTime.tryParse(timeStr);
      }
    }

    final rawCtKind = NodeValueParser.asString(normalized['ct_kind']) ??
        NodeValueParser.asString(normalized['ctKind']) ??
        'general';
    final parentFromCol = (NodeValueParser.asString(normalized['parent']) ??
            NodeValueParser.asString(normalized['parent_it_id']) ??
            NodeValueParser.asString(normalized['parentItId']) ??
            '')
        .trim();
    final parentItId = parentFromCol.isNotEmpty
        ? parentFromCol
        : _parseParentItId(rawCtKind);
    final hasParent = (parentItId ?? '').trim().isNotEmpty;
    // ct_kind는 상품 종류만 (legacy supply_add| 는 general로 취급)
    final productCtKind = rawCtKind.trim().toLowerCase().startsWith('supply_add|')
        ? 'general'
        : (rawCtKind.trim().isEmpty ? 'general' : rawCtKind.trim());
    final normalizedCtKind = _normalizeKind(productCtKind);
    final parsedKind = hasParent && normalizedCtKind != 'general'
        ? 'supply_add'
        : (NodeValueParser.asString(normalized['kind']) ??
            _parseKindToken(productCtKind));
    final effectiveParentItId = normalizedCtKind == 'general'
        ? null
        : (hasParent ? parentItId : null);
    final hpReservationDate =
        NodeValueParser.asString(normalized['hp_rsvt_date'])?.trim();
    final hpReservationStart =
        NodeValueParser.asString(normalized['hp_rsvt_stime'])?.trim();
    final hpReservationEnd =
        NodeValueParser.asString(normalized['hp_rsvt_etime'])?.trim();
    final parsedReservationDate = reservationDate ??
        _parseReservationDateCandidates([
          NodeValueParser.asString(normalized['reservation_date']),
          NodeValueParser.asString(normalized['reservationDate']),
          hpReservationDate,
        ]);

    final resolvedImage = pickBestImageRawFromJson(normalized);

    return CartItem(
      ctId: _parseInt(normalized['ct_id'] ?? normalized['ctId']),
      odId: NodeValueParser.asString(normalized['od_id']) ??
          NodeValueParser.asString(normalized['odId']) ??
          '',
      mbId: NodeValueParser.asString(normalized['mb_id']) ??
          NodeValueParser.asString(normalized['mbId']) ??
          '',
      itId: NodeValueParser.asString(normalized['it_id']) ??
          NodeValueParser.asString(normalized['itId']) ??
          '',
      itName: NodeValueParser.asString(normalized['it_name']) ??
          NodeValueParser.asString(normalized['itName']) ??
          '',
      itSubject: NodeValueParser.asString(normalized['it_subject']) ??
          NodeValueParser.asString(normalized['itSubject']),
      ctStatus: NodeValueParser.asString(normalized['ct_status']) ??
          NodeValueParser.asString(normalized['ctStatus']) ??
          '',
      ctPrice: _parseInt(normalized['ct_price'] ?? normalized['ctPrice'] ?? 0),
      ctOption: NodeValueParser.asString(normalized['ct_option']) ??
          NodeValueParser.asString(normalized['ctOption']) ??
          '',
      ctQty: _parseInt(normalized['ct_qty'] ?? normalized['ctQty'] ?? 1),
      ioId: NodeValueParser.asString(normalized['io_id']) ??
          NodeValueParser.asString(normalized['ioId']),
      ioPrice: normalized['io_price'] != null || normalized['ioPrice'] != null
          ? _parseInt(normalized['io_price'] ?? normalized['ioPrice'])
          : null,
      ioType: _parseInt(normalized['io_type'] ?? normalized['ioType'] ?? 0)
          .clamp(0, 3),
      ctKind: productCtKind,
      kind: parsedKind,
      itKind: _parseItKind(
        NodeValueParser.asString(normalized['it_kind']) ??
            NodeValueParser.asString(normalized['itKind']) ??
            NodeValueParser.asString(normalized['product_kind']) ??
            NodeValueParser.asString(normalized['productKind']),
      ),
      parentItId: effectiveParentItId,
      itSupplyItems: NodeValueParser.asString(normalized['it_supply_items']) ??
          NodeValueParser.asString(normalized['itSupplyItems']),
      ctTime: ctTime,
      doctorName: doctorName ??
          NodeValueParser.asString(normalized['hp_doc_name']) ??
          NodeValueParser.asString(normalized['doctor_name']) ??
          NodeValueParser.asString(normalized['doctorName']),
      reservationDate: parsedReservationDate,
      reservationTime: reservationTime ??
          NodeValueParser.asString(normalized['reservation_time']) ??
          NodeValueParser.asString(normalized['reservationTime']) ??
          _composeReservationTimeRange(
            hpReservationStart,
            hpReservationEnd,
          ),
      imageUrl: resolvedImage,
      productType: NodeValueParser.asString(normalized['product_type']) ??
          NodeValueParser.asString(normalized['productType']) ??
          '한의약품',
      ctMbInf: NodeValueParser.asString(
              normalized['ct_mb_inf'] ?? normalized['ctMbInf']) ??
          '',
      pointUsageRate: _parsePointUsageRate(
        normalized['point_usage_rate'] ??
            normalized['pointUsageRate'] ??
            normalized['it_point_usage_rate'],
        normalizedCtKind,
      ),
      ctSelect: _parseCtSelect(normalized['ct_select'] ?? normalized['ctSelect']),
      isAvailable: _parseIsAvailable(
        normalized['is_available'] ?? normalized['isAvailable'],
      ),
      unavailableReason: NodeValueParser.asString(
        normalized['unavailable_reason'] ?? normalized['unavailableReason'],
      ),
    );
  }

  /// API가 주는 여러 이미지 필드 중, CDN에서 실제 이미지로 열리는 **`thumb-` 등 썸네일 경로**를 우선합니다.
  /// (`.../원본.jpg`만 있으면 Cafe24가 HTML을 주어 프록시가 415를 내는 경우가 있음)
  static String? pickBestImageRawFromJson(Map<String, dynamic> normalized) {
    final candidates = <String>[];
    void push(String? s) {
      final t = (s ?? '').trim();
      if (t.isEmpty || t.toLowerCase() == 'null') return;
      if (candidates.contains(t)) return;
      candidates.add(t);
    }

    const rootKeys = <String>[
      'image_url',
      'imageUrl',
      'thumb_url',
      'thumbnail_url',
      'it_thumb',
      'it_mobile_img',
      'product_image',
      'thumbnail',
      'item_image',
      'img_url',
      'it_img',
      'it_img1',
      'it_img2',
      'it_img3',
    ];
    for (final k in rootKeys) {
      push(NodeValueParser.asString(normalized[k]));
    }

    for (final nestedKey in ['product', 'item', 'goods', 'it', 'g5_item']) {
      final raw = normalized[nestedKey];
      if (raw is! Map) continue;
      final m = NodeValueParser.normalizeMap(Map<String, dynamic>.from(raw));
      for (final k in rootKeys) {
        push(NodeValueParser.asString(m[k]));
      }
      for (var i = 1; i <= 9; i++) {
        push(NodeValueParser.asString(m['it_img$i']));
        push(NodeValueParser.asString(m['itImg$i']));
      }
    }

    for (final c in candidates) {
      final lower = c.toLowerCase();
      if (lower.contains('thumb-') ||
          lower.contains('/thumb_') ||
          lower.contains('_100x') ||
          lower.contains('_200x')) {
        return c;
      }
    }
    return candidates.isNotEmpty ? candidates.first : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'ct_id': ctId,
      'od_id': odId,
      'mb_id': mbId,
      'it_id': itId,
      'it_name': itName,
      'it_subject': itSubject,
      'ct_status': ctStatus,
      'ct_price': ctPrice,
      'ct_option': ctOption,
      'ct_qty': ctQty,
      'io_id': ioId,
      'io_price': ioPrice,
      'io_type': ioType,
      'ct_kind': ctKind,
      'kind': kind,
      'it_kind': itKind,
      'parent': parentItId ?? '',
      'parent_it_id': parentItId,
      'it_supply_items': itSupplyItems,
      'ct_time': ctTime?.toIso8601String(),
      'doctor_name': doctorName,
      'reservation_date': reservationDate?.toIso8601String(),
      'reservation_time': reservationTime,
      'image_url': imageUrl,
      'product_type': productType,
      'ct_mb_inf': ctMbInf,
      'point_usage_rate': pointUsageRate,
      'ct_select': ctSelect ? 1 : 0,
    };
  }

  static bool _parseIsAvailable(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return true;
    return s != '0' && s != 'false' && s != 'n';
  }

  static bool _parseCtSelect(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed == '1' || trimmed.toLowerCase() == 'true';
    }
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static String _normalizeKind(String kind) {
    final cleaned =
        kind.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim().toLowerCase();
    if (cleaned.isEmpty) return 'general';
    return cleaned;
  }

  static String _parseKindToken(String rawCtKind) {
    final cleaned = _normalizeKind(rawCtKind);
    if (cleaned.startsWith('supply_add|')) return 'supply_add';
    if (cleaned == 'prescription') return 'prescription';
    return 'general';
  }

  static String? _parseItKind(String? raw) {
    final cleaned = _normalizeKind(raw ?? '');
    if (cleaned.isEmpty || cleaned == 'general') {
      return cleaned.isEmpty ? null : 'general';
    }
    if (cleaned == 'prescription') return 'prescription';
    return cleaned;
  }

  static String? _parseParentItId(String rawCtKind) {
    final cleaned = rawCtKind.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    const prefix = 'supply_add|';
    if (cleaned.toLowerCase().startsWith(prefix)) {
      final id = cleaned.substring(prefix.length).trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  static int _parsePointUsageRate(dynamic value, String ctKind) {
    final parsed = _parseInt(value);
    if (parsed > 0) return parsed > 100 ? 100 : parsed;
    if (_normalizeKind(ctKind) == 'prescription') return 100;
    return 10;
  }

  static String? _composeReservationTimeRange(String? start, String? end) {
    final safeStart = start?.trim() ?? '';
    final safeEnd = end?.trim() ?? '';
    if (safeStart.isEmpty && safeEnd.isEmpty) return null;
    if (safeStart.isNotEmpty && safeEnd.isNotEmpty) {
      return '$safeStart ~ $safeEnd';
    }
    return safeStart.isNotEmpty ? safeStart : safeEnd;
  }

  static final RegExp _isoDateInString = RegExp(r'(\d{4}-\d{2}-\d{2})');

  static DateTime? _parseReservationDateCandidates(List<String?> candidates) {
    for (final raw in candidates) {
      final safe = (raw ?? '').trim();
      if (safe.isEmpty) continue;
      final embedded = _isoDateInString.firstMatch(safe);
      if (embedded != null) {
        final parsed = DateTime.tryParse(embedded.group(1)!);
        if (parsed != null) return parsed;
      }
      final normalized = safe.length >= 10 ? safe.substring(0, 10) : safe;
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String get formattedPrice {
    return '${lineAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}원';
  }

  bool get hasReservationSchedule {
    if (reservationDate != null) return true;
    final time = reservationTime?.trim() ?? '';
    return time.isNotEmpty;
  }

  bool get needsPrescriptionBooking =>
      !isSupplyAdd && isPrescription && !hasReservationSchedule;

  bool get isPrescription {
    if (isSupplyAdd) return false;

    final ck = _normalizeKind(ctKind);
    if (ck == 'general') return false;
    if (ck == 'prescription') return true;

    final k = _normalizeKind(kind);
    if (k == 'general') return false;
    if (k == 'prescription') return true;

    final ik = _normalizeKind(itKind ?? '');
    if (ik == 'general') return false;
    if (ik == 'prescription') return true;

    if (doctorName != null && doctorName!.trim().isNotEmpty) return true;
    if (hasReservationSchedule) return true;
    return false;
  }
}
