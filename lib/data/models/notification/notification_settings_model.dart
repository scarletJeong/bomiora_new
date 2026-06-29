/// 앱 알림 수신 동의 설정
class NotificationSettingsModel {
  const NotificationSettingsModel({
    this.orderAgree = false,
    this.marketingAgree = false,
    this.appPushAgree = false,
    this.smsAgree = false,
  });

  final bool orderAgree;
  final bool marketingAgree;
  final bool appPushAgree;
  final bool smsAgree;

  NotificationSettingsModel copyWith({
    bool? orderAgree,
    bool? marketingAgree,
    bool? appPushAgree,
    bool? smsAgree,
  }) {
    return NotificationSettingsModel(
      orderAgree: orderAgree ?? this.orderAgree,
      marketingAgree: marketingAgree ?? this.marketingAgree,
      appPushAgree: appPushAgree ?? this.appPushAgree,
      smsAgree: smsAgree ?? this.smsAgree,
    );
  }

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    bool readBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    return NotificationSettingsModel(
      orderAgree: readBool(json['order_agree'] ?? json['orderAgree']),
      marketingAgree:
          readBool(json['marketing_agree'] ?? json['marketingAgree']),
      appPushAgree: readBool(json['app_push_agree'] ?? json['appPushAgree']),
      smsAgree: readBool(json['sms_agree'] ?? json['smsAgree']),
    );
  }

  Map<String, dynamic> toJson() => {
        'order_agree': orderAgree ? 1 : 0,
        'marketing_agree': marketingAgree ? 1 : 0,
        'app_push_agree': appPushAgree ? 1 : 0,
        'sms_agree': smsAgree ? 1 : 0,
      };
}
