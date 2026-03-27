import '../../../core/utils/node_value_parser.dart';

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
  final String? wrOption; // html1, html2, secret 등의 옵션
  final int? wrIsComment; // 답변 여부 (0=답변없음, 1=답변있음)
  
  // 답변 여부 (wr_is_comment = 1 이면 답변 있음)
  bool get hasReply => wrIsComment == 1;
  
  // HTML 포함 여부 (wr_option에 'html1' 또는 'html2' 포함)
  bool get isHtml => wrOption?.contains('html') ?? false;

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
    this.wrOption,
    this.wrIsComment,
  });

  factory Contact.fromJson(Map<dynamic, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(Map<String, dynamic>.from(json));

    final wrReplyRaw = NodeValueParser.asString(normalized['wr_reply'])?.trim() ?? '';
    final wr7Raw = NodeValueParser.asString(normalized['wr_7'])?.trim() ?? '';
    final mergedReply = wrReplyRaw.isNotEmpty ? wrReplyRaw : wr7Raw;

    return Contact(
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
      wrHit: NodeValueParser.asInt(normalized['wr_hit']) ?? 0,
      wrOption: NodeValueParser.asString(normalized['wr_option']),
      wrIsComment: NodeValueParser.asInt(normalized['wr_is_comment']),
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
      'wr_option': wrOption,
      'wr_is_comment': wrIsComment,
    };
  }
  
  /// 질문 글 본문: `wr_content`만 사용(답변 필드 `wr_reply`/`wr_7`과 섞지 않음)
  String get plainQuestionBody {
    return _toPlainText(wrContent);
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

