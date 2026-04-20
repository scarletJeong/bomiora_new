import 'dart:convert';
import 'dart:typed_data';

/// 메인 홈 `bomiora_main_review` API 응답 (`GET /api/user/reviews/main`)
class MainHomeReviewModel {
  final int mrNo;
  final String? itId;
  final String? mbId;
  final String? mrTitle;
  final String? mrContent;
  final String? mrSummary;
  final String? productImage;
  final List<String> images;

  const MainHomeReviewModel({
    required this.mrNo,
    this.itId,
    this.mbId,
    this.mrTitle,
    this.mrContent,
    this.mrSummary,
    this.productImage,
    this.images = const [],
  });

  factory MainHomeReviewModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    List<String> images = [];
    if (rawImages is List) {
      images = rawImages
          .map(_decodeTextField)
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return MainHomeReviewModel(
      mrNo: _parseInt(json['mrNo']),
      itId: _decodeTextField(json['itId']),
      mbId: _decodeTextField(json['mbId']),
      mrTitle: _decodeTextField(json['mrTitle']),
      mrContent: _decodeTextField(json['mrContent']),
      mrSummary: _decodeTextField(json['mrSummary']),
      productImage: _decodeTextField(json['productImage']),
      images: images,
    );
  }

  /// Node mysql2 Buffer 가 JSON 으로 오면 `{ "type": "Buffer", "data": [...] }` 형태 — UTF-8 로 복원
  static String? _decodeTextField(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      if (m['type'] == 'Buffer' && m['data'] is List) {
        try {
          final bytes = (m['data'] as List)
              .map((e) => (e as num).toInt())
              .toList();
          final s = utf8.decode(Uint8List.fromList(bytes));
          return s.isEmpty ? null : s;
        } catch (_) {
          return null;
        }
      }
    }
    return v.toString();
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// 카드 상단 한 줄 (제목 우선)
  String get headline {
    final t = mrTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '리뷰';
  }

  /// 카드 본문 2줄 요약
  String get bodyText {
    final s = mrSummary?.trim();
    if (s != null && s.isNotEmpty) return s;
    final c = mrContent?.trim();
    if (c != null && c.isNotEmpty) return c;
    return '';
  }
}
