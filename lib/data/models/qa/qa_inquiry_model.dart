import '../../../core/utils/node_value_parser.dart';

class QaInquiry {
  final int wrId;
  final String wrSubject;
  final String wrContent;
  final String mbId;
  final String wrName;
  final String wrEmail;
  final String wrDatetime;
  final String wrLast;
  final int wrComment;
  final String wrReply;
  final int wrParent;
  final String? caName;
  final String? wr6;
  final int wrHit;
  final String? wrOption; // html1, html2, secret 등의 옵션
  final int? wrIsComment; // 답변 여부 (0=답변없음, 1=답변있음)
  /// 스레드 내 추가질문 개수(원글 제외)
  final int followupCount;
  /// 스레드 최신 글(원글/추가질문) ID
  final int latestWrId;
  /// 스레드 최신 글(원글/추가질문)의 답변 여부(0/1)
  final int latestWrIsComment;
  /// 문의 종료 여부 (`wr_8` / `is_closed` 등)
  final bool isClosed;
  
  // 답변 여부 (wr_is_comment = 1 이면 답변 있음)
  bool get hasReply => wrIsComment == 1;
  bool get latestAnswered => latestWrIsComment == 1;
  
  // HTML 포함 여부 (wr_option에 'html1' 또는 'html2' 포함)
  bool get isHtml => wrOption?.contains('html') ?? false;

  QaInquiry({
    required this.wrId,
    required this.wrSubject,
    required this.wrContent,
    required this.mbId,
    required this.wrName,
    required this.wrEmail,
    required this.wrDatetime,
    required this.wrLast,
    required this.wrComment,
    required this.wrReply,
    required this.wrParent,
    this.caName,
    this.wr6,
    required this.wrHit,
    this.wrOption,
    this.wrIsComment,
    this.followupCount = 0,
    this.latestWrId = 0,
    this.latestWrIsComment = 0,
    this.isClosed = false,
  });

  static bool _parseIsClosed(Map<String, dynamic> normalized) {
    if (normalized.containsKey('is_closed')) {
      return NodeValueParser.asInt(normalized['is_closed']) == 1;
    }
    // is_closed 필드가 없는 구 API 응답만 wr_8 레거시 사용
    final wr8 = NodeValueParser.asString(normalized['wr_8'])?.trim() ?? '';
    return wr8 == '1' ||
        wr8.toLowerCase() == 'closed' ||
        wr8 == 'Y';
  }

  factory QaInquiry.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));

    final wrReplyRaw = NodeValueParser.asString(normalized['wr_reply'])?.trim() ?? '';
    final wr7Raw = NodeValueParser.asString(normalized['wr_7'])?.trim() ?? '';
    final mergedReply = wrReplyRaw.isNotEmpty ? wrReplyRaw : wr7Raw;

    return QaInquiry(
      wrId: NodeValueParser.asInt(normalized['wr_id']) ?? 0,
      wrSubject: NodeValueParser.asString(normalized['wr_subject']) ?? '',
      wrContent: NodeValueParser.asString(normalized['wr_content']) ?? '',
      mbId: NodeValueParser.asString(normalized['mb_id']) ?? '',
      wrName: NodeValueParser.asString(normalized['wr_name']) ?? '',
      wrEmail: NodeValueParser.asString(normalized['wr_email']) ?? '',
      wrDatetime: NodeValueParser.asString(normalized['wr_datetime']) ?? '',
      wrLast: NodeValueParser.asString(normalized['wr_last']) ?? '',
      wrComment: NodeValueParser.asInt(normalized['wr_comment']) ?? 0,
      wrReply: mergedReply,
      wrParent: NodeValueParser.asInt(normalized['wr_parent']) ?? 0,
      caName: NodeValueParser.asString(normalized['ca_name']),
      wr6: NodeValueParser.asString(normalized['wr_6']),
      wrHit: NodeValueParser.asInt(normalized['wr_hit']) ?? 0,
      wrOption: NodeValueParser.asString(normalized['wr_option']),
      wrIsComment: NodeValueParser.asInt(normalized['wr_is_comment']),
      followupCount: NodeValueParser.asInt(normalized['followup_count']) ?? 0,
      latestWrId: NodeValueParser.asInt(normalized['latest_wr_id']) ?? 0,
      latestWrIsComment:
          NodeValueParser.asInt(normalized['latest_wr_is_comment']) ?? 0,
      isClosed: _parseIsClosed(normalized),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wr_id': wrId,
      'wr_subject': wrSubject,
      'wr_content': wrContent,
      'mb_id': mbId,
      'wr_name': wrName,
      'wr_email': wrEmail,
      'wr_datetime': wrDatetime,
      'wr_last': wrLast,
      'wr_comment': wrComment,
      'wr_reply': wrReply,
      'wr_parent': wrParent,
      'ca_name': caName,
      'wr_6': wr6,
      'wr_hit': wrHit,
      'wr_option': wrOption,
      'wr_is_comment': wrIsComment,
    };
  }
  
  /// 질문 글 본문: `wr_content`만 사용(답변 필드 `wr_reply`/`wr_7`과 섞지 않음)
  String get plainQuestionBody {
    return _toPlainText(wrContent);
  }

  /// 신규(비표시) subject 여부
  /// - 정확히 `상품`/`주문`/`기타`
  /// - `[상품 문의]` / `[주문 문의]` 로 시작하는 메타 블록
  bool get isStructuredSubject {
    final s = wrSubject.trim();
    if (s.isEmpty) return false;
    if (s == '상품' || s == '주문' || s == '기타') return true;
    return s.startsWith('[상품 문의]') || s.startsWith('[주문 문의]');
  }

  /// 구 제목: 자유 형식 제목 (위 structured가 아닌 경우)
  bool get isLegacySubjectTitle {
    final s = wrSubject.trim();
    if (s.isEmpty) return false;
    return !isStructuredSubject;
  }

  /// 문의 카테고리 라벨 (목록 배지용) — `주문|예약/결제|결제 문의` 형태면 앞부분
  String get inquiryCategoryLabel {
    final ca = caName?.trim() ?? '';
    if (ca.isNotEmpty) {
      final head = ca.split('|').first.trim();
      if (head == '상품' || head == '주문' || head == '기타') return head;
    }
    final s = wrSubject.trim();
    if (s == '상품' || s.startsWith('[상품 문의]')) return '상품';
    if (s == '주문' || s.startsWith('[주문 문의]')) return '주문';
    if (s == '기타') return '기타';
    return '';
  }

  /// 큰 카테고리 (`ca_name` 2번째) — 예: 상품문의, 예약/결제
  String get inquiryMajorLabel {
    final ca = caName?.trim() ?? '';
    if (!ca.contains('|')) return '';
    final parts = ca.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 3) return parts[1];
    return '';
  }

  /// 상세 칩 (`ca_name` 마지막) — 예: 결제 문의, 배송
  /// 구버전 `주문|결제` 도 지원
  String get inquiryDetailLabel {
    final ca = caName?.trim() ?? '';
    if (!ca.contains('|')) return '';
    final parts = ca.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return '';
    return parts.last;
  }

  String? _subjectField(String key) {
    final s = wrSubject.trim();
    if (s.isEmpty) return null;
    final m = RegExp(
      '^${RegExp.escape(key)}:\\s*(.+)\$',
      multiLine: true,
    ).firstMatch(s);
    return m?.group(1)?.trim();
  }

  String? get subjectProductName => _subjectField('상품');
  String? get subjectBrandName => _subjectField('브랜드');
  String? get subjectItSubject => _subjectField('품목');
  String? get subjectProductCode => _subjectField('상품코드');
  String? get subjectOrderId => _subjectField('주문번호');
  String? get subjectOrderDate => _subjectField('주문일');
  String? get subjectOptionText => _subjectField('옵션');
  String? get subjectTabLabel => _subjectField('탭');
  String? get subjectImageUrl => _subjectField('이미지');
  int? get subjectPrice {
    final raw = _subjectField('가격');
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  /// 목록 카드 제목 — `주문 · 결제` (카테고리 · 선택 칩)
  String get listCardTitle {
    final cat = inquiryCategoryLabel;
    final detail = inquiryDetailLabel;
    if (cat.isNotEmpty && detail.isNotEmpty) {
      return '$cat · $detail';
    }
    if (cat.isNotEmpty) return '$cat 문의';

    if (isLegacySubjectTitle) {
      final s = wrSubject.trim();
      return s.length > 40 ? '${s.substring(0, 40)}…' : s;
    }
    final product = subjectProductName;
    if (product != null && product.isNotEmpty) {
      return product.length > 40 ? '${product.substring(0, 40)}…' : product;
    }
    final orderId = subjectOrderId;
    if (orderId != null && orderId.isNotEmpty) return '주문 $orderId';
    final body = displayQuestionText.trim().replaceAll('\n', ' ');
    if (body.isEmpty) return '(내용 없음)';
    return body.length > 40 ? '${body.substring(0, 40)}…' : body;
  }

  /// 목록 카드 보조 문구 — 본문 미리보기
  String get listCardPreview {
    final body = displayQuestionText.trim().replaceAll('\n', ' ');
    if (body.isEmpty) return '';
    return body.length > 48 ? '${body.substring(0, 48)}…' : body;
  }

  /// 채팅 말풍선 표시용 본문
  /// - 신규 structured subject는 숨김
  /// - 구 제목만 본문 앞에 붙임
  /// - 예전에 content에 넣었던 메타 블록(`[…문의]…---`)은 본문에서 제거
  String get displayQuestionText {
    var body = _stripLegacyContentMeta(plainQuestionBody.trim());
    if (isLegacySubjectTitle) {
      final subject = wrSubject.trim();
      if (body.isEmpty) return subject;
      if (body.startsWith(subject)) return body;
      return '$subject\n$body';
    }
    return body;
  }

  /// 구버전: content 앞에 붙이던 메타 + `---` 구분선 제거
  String _stripLegacyContentMeta(String body) {
    if (body.isEmpty) return body;
    if (!(body.startsWith('[상품 문의]') || body.startsWith('[주문 문의]'))) {
      return body;
    }
    final sep = RegExp(r'\n---\s*\n').firstMatch(body);
    if (sep != null) {
      return body.substring(sep.end).trim();
    }
    final sep2 = RegExp(r'\n---\s*$').firstMatch(body);
    if (sep2 != null) return '';
    return body;
  }

  /// 일반 본문(답변 행 등): 본문 우선, 없으면 답변 필드
  String getPlainTextContent() {
    final primary = wrContent.trim().isNotEmpty ? wrContent : wrReply;
    return _toPlainText(primary);
  }

  String _toPlainText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final looksHtml = isHtml || t.contains(RegExp(r'<[^>]+>'));
    if (!looksHtml) return t;

    return t
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .trim();
  }
}

