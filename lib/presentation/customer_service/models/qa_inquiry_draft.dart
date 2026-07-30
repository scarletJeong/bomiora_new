/// 1:1 문의 작성 전 선택 컨텍스트 + 칩/안내 문구
class QaInquiryDraft {
  final String category; // 상품 | 주문 | 기타
  /// 큰 카테고리 (상품문의, 예약/결제, …) — 주문/상품 공통
  final String? majorCategory;
  final String? itId;
  final String? productKind;
  final String? productName;
  final String? brandName;
  final String? imageUrl;
  final int? price;
  final String? odId;
  final String? orderDate;
  /// 장바구니/주문 옵션 표시용
  final String? optionText;
  /// it_subject (상품명 위 표시)
  final String? itSubject;
  /// 상품선택 탭명 (장바구니/찜한 상품, 주문/배송/취소)
  final String? selectTabLabel;

  const QaInquiryDraft({
    required this.category,
    this.majorCategory,
    this.itId,
    this.productKind,
    this.productName,
    this.brandName,
    this.imageUrl,
    this.price,
    this.odId,
    this.orderDate,
    this.optionText,
    this.itSubject,
    this.selectTabLabel,
  });

  bool get hasTarget =>
      (productName != null && productName!.trim().isNotEmpty) ||
      (odId != null && odId!.trim().isNotEmpty);

  /// 제목 컬럼: 상품/주문 메타는 subject에 저장(화면 비표시), 기타는 카테고리만
  String buildSubject(String message) {
    if (category == '상품' && hasTarget) {
      final buf = StringBuffer('[상품 문의]');
      if (brandName != null && brandName!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('브랜드: ${brandName!.trim()}');
      }
      if (itSubject != null && itSubject!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('품목: ${itSubject!.trim()}');
      }
      if (productName != null && productName!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품: ${productName!.trim()}');
      }
      if (optionText != null && optionText!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('옵션: ${optionText!.trim()}');
      }
      if (selectTabLabel != null && selectTabLabel!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('탭: ${selectTabLabel!.trim()}');
      }
      if (itId != null && itId!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품코드: ${itId!.trim()}');
      }
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('이미지: ${imageUrl!.trim()}');
      }
      if (price != null) {
        buf.writeln();
        buf.write('가격: $price');
      }
      return buf.toString();
    }
    if (category == '주문' && hasTarget) {
      final buf = StringBuffer('[주문 문의]');
      if (odId != null && odId!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('주문번호: ${odId!.trim()}');
      }
      if (orderDate != null && orderDate!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('주문일: ${orderDate!.trim()}');
      }
      if (brandName != null && brandName!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('브랜드: ${brandName!.trim()}');
      }
      if (itSubject != null && itSubject!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('품목: ${itSubject!.trim()}');
      }
      if (productName != null && productName!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품: ${productName!.trim()}');
      }
      if (optionText != null && optionText!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('옵션: ${optionText!.trim()}');
      }
      if (selectTabLabel != null && selectTabLabel!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('탭: ${selectTabLabel!.trim()}');
      }
      if (itId != null && itId!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품코드: ${itId!.trim()}');
      }
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('이미지: ${imageUrl!.trim()}');
      }
      if (price != null) {
        buf.writeln();
        buf.write('가격: $price');
      }
      return buf.toString();
    }
    return category;
  }

  static String? formatOptionText({String? ctOption, String? itSubject}) {
    final opt = (ctOption ?? '').trim();
    final sub = (itSubject ?? '').trim();
    if (opt.contains(' / ')) {
      final parts = opt
          .split(' / ')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length >= 2) return parts.join(' | ');
    }
    if (sub.isNotEmpty && opt.isNotEmpty) return '$sub | $opt';
    if (opt.isNotEmpty) return opt;
    if (sub.isNotEmpty) return sub;
    return null;
  }

  /// 본문에는 사용자가 입력한 메시지만이 들어감
  String buildContent(String message) => message.trim();

  // ── 칩 / CS 안내 (작성·상세 공통) ──

  static const String askPrompt = '어떤 것이 궁금하신가요?';

  /// 기타 카테고리 진입 시 CS 첫 안내 (칩 없음)
  static const String etcAskPrompt = '안녕하세요. 보미오라 한의원입니다.\n 궁금한 내용을 입력해 주세요.';

  /// 주문/상품 공통 큰 카테고리
  static const List<String> majorCategories = [
    '상품문의',
    '예약/결제',
    '배송',
    '교환/반품',
    '취소/환불',
    '이벤트/쿠폰',
  ];

  static List<String> topicsFor(String category, [String? majorCategory]) {
    final major = (majorCategory ?? '').trim();
    if (major.isEmpty) return const [];

    if (category == '상품') {
      switch (major) {
        case '상품문의':
          return const [
            '단계추천',
            '복용방법',
            '입고 일정',
            '임산부 복용',
            '위고비/마운자로병행',
            '유통기한',
            '기타',
          ];
        case '예약/결제':
          return const ['예약 방법', '결제 문의', '기타'];
        case '배송':
          return const ['배송비 문의', '해외배송', '기타'];
        case '교환/반품':
          return const ['교환문의', '반품문의', '기타'];
        case '취소/환불':
          return const ['취소 문의', '환불 문의', '기타'];
        case '이벤트/쿠폰':
          return const ['이벤트 문의', '쿠폰문의', '적립금 문의', '기타'];
        default:
          return const [];
      }
    }

    if (category == '주문') {
      switch (major) {
        case '상품문의':
          return const [
            '복용방법',
            '입고 일정',
            '임산부 복용',
            '위고비/마운자로병행',
            '유통기한',
            '기타',
          ];
        case '예약/결제':
          return const [
            '예약 시간 변경',
            '결제 문의',
            '제품 단계 변경',
            '현금영수증',
            '기타',
          ];
        case '배송':
          return const ['배송비 변경', '해외배송', '배송조회', '배송오류', '기타'];
        case '교환/반품':
          return const ['교환 신청', '반품 신청', '기타'];
        case '취소/환불':
          return const ['취소 문의', '환불 문의', '기타'];
        case '이벤트/쿠폰':
          return const ['이벤트 문의', '쿠폰문의', '적립금 문의', '기타'];
        default:
          return const [];
      }
    }

    return const [];
  }

  static String guideMessage(String category) {
    switch (category) {
      case '주문':
        return '안녕하세요. 보미오라 한의원입니다.\n [주문문의]에서 궁금하신 사항을 선택해주세요.';
      case '상품':
        return '안녕하세요. 보미오라 한의원입니다.\n [상품문의]에서 궁금하신 사항을 선택해주세요.';
      case '기타':
        return '안녕하세요. 보미오라 한의원입니다.\n 궁금하신 사항을 입력해주세요.';
      default:
        return '';
    }
  }
}
