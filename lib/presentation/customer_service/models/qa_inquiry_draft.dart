/// 1:1 문의 작성 전 선택 컨텍스트 + 칩/안내 문구
class QaInquiryDraft {
  final String category; // 상품 | 주문 | 기타
  final String? itId;
  final String? productKind;
  final String? productName;
  final String? brandName;
  final String? imageUrl;
  final int? price;
  final String? odId;
  final String? orderDate;

  const QaInquiryDraft({
    required this.category,
    this.itId,
    this.productKind,
    this.productName,
    this.brandName,
    this.imageUrl,
    this.price,
    this.odId,
    this.orderDate,
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
      if (productName != null && productName!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품: ${productName!.trim()}');
      }
      if (itId != null && itId!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품코드: ${itId!.trim()}');
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
      if (productName != null && productName!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품: ${productName!.trim()}');
      }
      if (itId != null && itId!.trim().isNotEmpty) {
        buf.writeln();
        buf.write('상품코드: ${itId!.trim()}');
      }
      return buf.toString();
    }
    return category;
  }

  /// 본문에는 사용자가 입력한 메시지만이 들어감
  String buildContent(String message) => message.trim();

  // ── 칩 / CS 안내 (작성·상세 공통) ──

  static const String askPrompt = '어떤 것이 궁금하신가요?';

  static const List<String> orderTopics = [
    '결제',
    '배송 전 변경',
    '배송',
    '취소',
    '교환',
    '반품',
    '기타',
  ];

  static const List<String> productTopics = [
    '배송',
    '옵션',
    '기타',
  ];

  static const List<String> etcTopics = [
    '결제/환불',
    '이벤트',
    '쿠폰/포인트',
    '기타',
  ];

  static List<String> topicsFor(String category) {
    switch (category) {
      case '주문':
        return orderTopics;
      case '상품':
        return productTopics;
      case '기타':
        return etcTopics;
      default:
        return const [];
    }
  }

  static String guideMessage(String category) {
    switch (category) {
      case '주문':
        return '안녕하세요. 보미오라입니다.\n먼저 주문문의에서 궁금하신 사항에 대해 선택해주세요.';
      case '상품':
        return '안녕하세요. 보미오라입니다.\n먼저 상품관련 궁금하신 사항에 대해 선택해주세요.';
      case '기타':
        return '안녕하세요. 보미오라입니다.\n먼저 궁금하신 사항에 대해 선택해주세요.';
      default:
        return '';
    }
  }

  /// 기타 칩 선택 시 Bomi CS 1차 안내 (내용은 추후 업데이트 가능)
  static String etcTopicGuide(String topic) {
    switch (topic) {
      case '결제/환불':
        return '결제·환불 관련 안내입니다.\n\n'
            '· 결제 내역은 마이페이지 > 주문내역에서 확인하실 수 있어요.\n'
            '· 환불은 결제 수단에 따라 영업일 기준 3~7일 소요될 수 있어요.\n\n'
            '더 자세한 안내는 추후 업데이트될 예정입니다.';
      case '이벤트':
        return '이벤트 관련 안내입니다.\n\n'
            '· 진행 중인 이벤트는 앱 홈·이벤트 페이지에서 확인해주세요.\n'
            '· 당첨·참여 확인은 이벤트별 유의사항을 참고해주세요.\n\n'
            '더 자세한 안내는 추후 업데이트될 예정입니다.';
      case '쿠폰/포인트':
        return '쿠폰·포인트 관련 안내입니다.\n\n'
            '· 보유 쿠폰/포인트는 마이페이지에서 확인하실 수 있어요.\n'
            '· 유효기간이 지난 쿠폰·포인트는 사용이 어려울 수 있어요.\n\n'
            '더 자세한 안내는 추후 업데이트될 예정입니다.';
      case '기타':
      default:
        return '기타 문의 관련 안내입니다.\n\n'
            '· 자주 묻는 내용은 고객센터 FAQ에서도 확인하실 수 있어요.\n\n'
            '더 자세한 안내는 추후 업데이트될 예정입니다.';
    }
  }
}
