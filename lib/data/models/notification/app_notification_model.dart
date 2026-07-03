class AppNotificationItem {
  AppNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.createdAt,
    this.isRead = false,
    this.type,
    this.linkId,
  });

  final String id;
  final String category;
  final String title;
  final String? description;
  final DateTime createdAt;
  final bool isRead;
  final String? type;
  final String? linkId;

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      category: category,
      title: title,
      description: description,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      type: type,
      linkId: linkId,
    );
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final readRaw = json['is_read'] ?? json['isRead'] ?? json['read'];
    final isRead = readRaw == true ||
        readRaw == 1 ||
        readRaw == '1' ||
        readRaw == 'Y' ||
        readRaw == 'y';

    final createdRaw = json['created_at'] ??
        json['createdAt'] ??
        json['reg_date'] ??
        json['date'];
    DateTime createdAt = DateTime.now();
    if (createdRaw is String && createdRaw.trim().isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw) ?? createdAt;
    }

    final type = json['type']?.toString();
    final categoryRaw = json['category'] ?? json['noti_category'];
    final category = (categoryRaw != null && categoryRaw.toString().trim().isNotEmpty)
        ? categoryRaw.toString()
        : _categoryLabel(type);

    final idRaw = json['id'] ?? json['notification_id'] ?? json['noti_id'];
    final id = idRaw?.toString().trim() ?? '';

    return AppNotificationItem(
      id: id.isNotEmpty
          ? id
          : '${createdAt.millisecondsSinceEpoch}_${type ?? 'push'}',
      category: category,
      title: '${json['title'] ?? json['noti_title'] ?? ''}',
      description: (json['description'] ??
              json['body'] ??
              json['noti_body'] ??
              json['content'])
          ?.toString(),
      createdAt: createdAt,
      isRead: isRead,
      type: type,
      linkId: json['link_id']?.toString() ??
          json['wr_id']?.toString() ??
          json['id']?.toString(),
    );
  }

  static String _categoryLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'login':
        return '로그인';
      case 'contact':
      case 'inquiry':
      case 'qna':
        return '1:1문의';
      case 'order':
        return '결제완료';
      case 'delivery':
        return '배송시작';
      case 'point':
        return '포인트 적립';
      case 'announcement':
      case 'notice':
        return '공지사항';
      case 'event':
        return '이벤트';
      default:
        return '알림';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        if (description != null) 'description': description,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        if (type != null) 'type': type,
        if (linkId != null) 'link_id': linkId,
      };

  String get formattedDate {
    final y = createdAt.year;
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    return '$y. $m. $d';
  }
}
