import '../../../core/utils/node_value_parser.dart';

class FaqModel {
  final int id;
  final String category;
  final String question;
  final String answer;
  final int viewCount;
  final String? writerName;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const FaqModel({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.viewCount,
    this.writerName,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    final normalized = NodeValueParser.normalizeMap(json);
    return FaqModel(
      id: NodeValueParser.asInt(normalized['id']) ?? 0,
      category: NodeValueParser.asString(normalized['category']) ?? '기타',
      question: NodeValueParser.asString(normalized['question']) ?? '',
      answer: NodeValueParser.asString(normalized['answer']) ?? '',
      viewCount: NodeValueParser.asInt(normalized['view_count']) ?? 0,
      writerName: NodeValueParser.asString(normalized['writer_name']),
      createdAt: NodeValueParser.asDateTime(normalized['created_at']),
      updatedBy: NodeValueParser.asString(normalized['updated_by']),
      updatedAt: NodeValueParser.asDateTime(normalized['updated_at']),
    );
  }
}
