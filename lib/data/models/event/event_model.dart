import '../../../core/utils/image_url_helper.dart';

class EventModel {
  final int wrId;
  final int wrNum;
  final String? caName;
  final String wrSubject;
  final String wrContent;
  final String? wrLink1;
  final String wrDatetime;
  final String? wrLast;
  final int wrHit;
  final String? wr1;
  final String? wr2;
  final bool isActive;

  EventModel({
    required this.wrId,
    required this.wrNum,
    this.caName,
    required this.wrSubject,
    required this.wrContent,
    this.wrLink1,
    required this.wrDatetime,
    this.wrLast,
    required this.wrHit,
    this.wr1,
    this.wr2,
    required this.isActive,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      wrId: json['wr_id'] ?? 0,
      wrNum: json['wr_num'] ?? 0,
      caName: json['ca_name'],
      wrSubject: json['wr_subject'] ?? '',
      wrContent: json['wr_content'] ?? '',
      wrLink1: json['wr_link1'],
      wrDatetime: json['wr_datetime'] ?? '',
      wrLast: json['wr_last'],
      wrHit: json['wr_hit'] ?? 0,
      wr1: json['wr_1'],
      wr2: json['wr_2'],
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wr_id': wrId,
      'wr_num': wrNum,
      'ca_name': caName,
      'wr_subject': wrSubject,
      'wr_content': wrContent,
      'wr_link1': wrLink1,
      'wr_datetime': wrDatetime,
      'wr_last': wrLast,
      'wr_hit': wrHit,
      'wr_1': wr1,
      'wr_2': wr2,
      'is_active': isActive,
    };
  }

  /// 이미지 URL 추출 (환경에 맞게 변환)
  String? getImageUrl() {
    final regex = RegExp(r'<img[^>]+src="([^"]+)"');
    final match = regex.firstMatch(wrContent);
    if (match != null) {
      final originalUrl = match.group(1)!;
      return ImageUrlHelper.convertToLocalUrl(originalUrl);
    }
    return null;
  }

  /// 텍스트 내용 추출 (HTML 태그 제거)
  String getPlainText() {
    String text = wrContent
        .replaceAll(RegExp(r'<img[^>]*>'), '') // 이미지 태그 제거
        .replaceAll(RegExp(r'<[^>]*>'), '') // 모든 HTML 태그 제거
        .replaceAll(RegExp(r'&nbsp;'), ' ') // 공백 변환
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .trim();
    return text;
  }
}

