import '../../../core/utils/node_value_parser.dart';

/// 이전글·다음글. 목록 이동에 쓰는 번호와 제목만 담는다.
class ContentNeighbor {
  const ContentNeighbor({this.id, this.title = ''});

  final int? id;
  final String title;

  factory ContentNeighbor.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    return ContentNeighbor(
      id: NodeValueParser.asInt(normalized['id']),
      title: (NodeValueParser.asString(normalized['title']) ?? '').trim(),
    );
  }

  static ContentNeighbor? fromDynamic(dynamic raw) {
    if (raw is! Map) return null;
    final neighbor = ContentNeighbor.fromJson(Map<String, dynamic>.from(raw));
    if (neighbor.id == null && neighbor.title.isEmpty) return null;
    return neighbor;
  }
}

/// 건강 콘텐츠 글. API JSON 키는 이 클래스에서만 읽는다.
class ContentPost {
  const ContentPost({
    this.id,
    this.category = '',
    this.title = '',
    this.thumbnailUrl = '',
    this.contentHtml = '',
    this.recommendCount = 0,
    this.userRecommended,
  });

  final int? id;
  final String category;
  final String title;
  final String thumbnailUrl;
  final String contentHtml;
  final int recommendCount;
  final bool? userRecommended;

  factory ContentPost.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    return ContentPost(
      id: NodeValueParser.asInt(normalized['id']),
      category: (NodeValueParser.asString(normalized['category']) ?? '').trim(),
      title: (NodeValueParser.asString(normalized['title']) ?? '').trim(),
      thumbnailUrl:
          (NodeValueParser.asString(normalized['thumbnail_url']) ?? '').trim(),
      contentHtml: NodeValueParser.asString(normalized['content_html']) ?? '',
      recommendCount: NodeValueParser.asInt(normalized['recommend_count']) ?? 0,
      userRecommended: _readRecommended(normalized),
    );
  }

  ContentPost copyWith({
    int? recommendCount,
    bool? userRecommended,
  }) {
    return ContentPost(
      id: id,
      category: category,
      title: title,
      thumbnailUrl: thumbnailUrl,
      contentHtml: contentHtml,
      recommendCount: recommendCount ?? this.recommendCount,
      userRecommended: userRecommended ?? this.userRecommended,
    );
  }

  static bool? _readRecommended(Map<String, dynamic> json) {
    if (!json.containsKey('user_recommended')) return null;
    final value = json['user_recommended'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == '1' || text == 'true') return true;
    if (text == '0' || text == 'false') return false;
    return null;
  }
}

/// 콘텐츠 상세 조회 결과. 추천 저장 응답은 여기 넣지 않는다.
class ContentDetailResult {
  const ContentDetailResult({
    required this.success,
    this.post,
    this.previous,
    this.next,
  });

  final bool success;
  final ContentPost? post;
  final ContentNeighbor? previous;
  final ContentNeighbor? next;

  ContentDetailResult copyWith({ContentPost? post}) {
    return ContentDetailResult(
      success: success,
      post: post ?? this.post,
      previous: previous,
      next: next,
    );
  }
}
