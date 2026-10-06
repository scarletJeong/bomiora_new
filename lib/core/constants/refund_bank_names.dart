/// 환불계좌 은행 목록. 마이페이지 환불계좌와 주문취소 팝업이 같이 씁니다.
abstract final class RefundBankNames {
  static const List<String> all = [
    'KB 국민은행',
    'SH 신한은행',
    'WOORI 우리은행',
    'HANA 하나은행',
    'NH 농협은행',
    'IBK 기업은행',
    'KAKAO 카카오뱅크',
    'K 케이뱅크',
    'TOSS 토스뱅크',
    'BS 부산은행',
    'DG 대구은행',
    'G 광주은행',
    'GN 경남은행',
    'JB 전북은행',
    'JJ 제주은행',
    'SH 수협은행',
    'U 우체국',
    'SC제일은행',
    'CITI 씨티은행',
  ];

  /// 저장된 은행명이 목록에 없으면 맨 앞에 붙여 선택이 유지되게 합니다.
  static List<String> withCurrent(String selected) {
    final bank = selected.trim();
    if (bank.isNotEmpty && !all.contains(bank)) {
      return [bank, ...all];
    }
    return all;
  }
}
