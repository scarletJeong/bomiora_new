import '../../../core/utils/node_value_parser.dart';

/// 마이페이지 배송지. 목록과 작성 화면이 같은 필드를 쓴다.
class ShippingAddress {
  final int? id;
  final String subject;
  final String name;
  final String phone;
  final String tel;
  final String zip1;
  final String zip2;
  final String addr1;
  final String addr2;
  final String addr3;
  final String memo;
  final bool isDefault;

  const ShippingAddress({
    this.id,
    this.subject = '',
    this.name = '',
    this.phone = '',
    this.tel = '',
    this.zip1 = '',
    this.zip2 = '',
    this.addr1 = '',
    this.addr2 = '',
    this.addr3 = '',
    this.memo = '',
    this.isDefault = false,
  });

  String get postalCode => '$zip1$zip2'.replaceAll(RegExp(r'[^0-9]'), '');

  String get detailAddress => '$addr2 $addr3'.trim();

  static ShippingAddress? tryParse(dynamic raw) {
    if (raw is ShippingAddress) return raw;
    if (raw is! Map) return null;
    return ShippingAddress.fromMap(Map<String, dynamic>.from(raw));
  }

  factory ShippingAddress.fromMap(Map<String, dynamic> json) {
    final item = NodeValueParser.normalizeMap(json);

    String text(List<String> keys) {
      for (final key in keys) {
        final value = NodeValueParser.asString(item[key])?.trim() ?? '';
        if (value.isNotEmpty && value != 'null') return value;
      }
      return '';
    }

    final defaultRaw = item['isDefault'] ?? item['adDefault'] ?? item['ad_default'];
    final defaultInt = NodeValueParser.asInt(defaultRaw);
    final defaultString = NodeValueParser.asString(defaultRaw)?.toLowerCase();
    final isDefault = defaultRaw == true ||
        defaultInt == 1 ||
        defaultString == 'y' ||
        defaultString == 'true';

    return ShippingAddress(
      id: NodeValueParser.asInt(item['id'] ?? item['adId'] ?? item['ad_id']),
      subject: text(['subject', 'adSubject', 'ad_subject']),
      name: text(['name', 'adName', 'ad_name']),
      phone: text(['phone', 'adHp', 'ad_hp']),
      tel: text(['tel', 'adTel', 'ad_tel']),
      zip1: text(['zip1', 'adZip1', 'ad_zip1']),
      zip2: text(['zip2', 'adZip2', 'ad_zip2']),
      addr1: text(['addr1', 'adAddr1', 'ad_addr1']),
      addr2: text(['addr2', 'adAddr2', 'ad_addr2']),
      addr3: text(['addr3', 'adAddr3', 'ad_addr3']),
      memo: text(['memo', 'adMemo', 'ad_memo']),
      isDefault: isDefault,
    );
  }

  /// 결제·주문 화면이 그대로 읽는 키.
  Map<String, dynamic> toMap() {
    return {
      'adId': id,
      'adSubject': subject,
      'adName': name,
      'adHp': phone,
      'adTel': tel,
      'adZip1': zip1,
      'adZip2': zip2,
      'adAddr1': addr1,
      'adAddr2': addr2,
      'adAddr3': addr3,
      'adMemo': memo,
      'adDefault': isDefault ? 1 : 0,
    };
  }
}
