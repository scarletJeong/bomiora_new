class Contact {
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
  final int wrHit;
  
  // 답변 여부 (댓글이 있으면 답변 완료)
  bool get hasReply => wrComment > 0;

  Contact({
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
    required this.wrHit,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      wrId: json['wr_id'] ?? 0,
      wrSubject: json['wr_subject'] ?? '',
      wrContent: json['wr_content'] ?? '',
      mbId: json['mb_id'] ?? '',
      wrName: json['wr_name'] ?? '',
      wrEmail: json['wr_email'] ?? '',
      wrDatetime: json['wr_datetime'] ?? '',
      wrLast: json['wr_last'] ?? '',
      wrComment: json['wr_comment'] ?? 0,
      wrReply: json['wr_reply'] ?? '',
      wrParent: json['wr_parent'] ?? 0,
      caName: json['ca_name'],
      wrHit: json['wr_hit'] ?? 0,
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
      'wr_hit': wrHit,
    };
  }
}

