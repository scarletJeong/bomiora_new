import '../../../core/utils/node_value_parser.dart';

class AnnouncementModel {
  final int id;
  final String title;
  final String content;
  final int viewCount;
  final bool isNotice;
  final String writerName;
  final String? createdBy;
  final String? createdAtRaw;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final String? imagePath;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.viewCount,
    required this.isNotice,
    required this.writerName,
    this.createdBy,
    this.createdAtRaw,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.imagePath,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    final createdAtParsed = NodeValueParser.asDateTime(
      normalized['created_at'] ?? normalized['createdAt'],
    );
    var createdAtRaw = NodeValueParser.asString(
      normalized['created_at'] ?? normalized['createdAt'],
    );
    if ((createdAtRaw == null || createdAtRaw.isEmpty) &&
        createdAtParsed != null) {
      createdAtRaw = createdAtParsed.toIso8601String();
    }

    return AnnouncementModel(
      id: NodeValueParser.asInt(normalized['id']) ?? 0,
      title: NodeValueParser.asString(normalized['title']) ?? '',
      content: NodeValueParser.asString(normalized['content']) ?? '',
      viewCount: NodeValueParser.asInt(normalized['view_count']) ?? 0,
      isNotice: normalized['is_notice'] == true ||
          normalized['is_notice'] == 1 ||
          normalized['is_notice']?.toString() == '1',
      writerName: NodeValueParser.asString(normalized['writer_name']) ?? '관리자',
      createdBy: NodeValueParser.asString(normalized['created_by']),
      createdAtRaw: createdAtRaw,
      createdAt: createdAtParsed,
      updatedBy: NodeValueParser.asString(normalized['updated_by']),
      updatedAt: NodeValueParser.asDateTime(normalized['updated_at']),
      imagePath: NodeValueParser.asString(normalized['image_path']),
    );
  }
}
