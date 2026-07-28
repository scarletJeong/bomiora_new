import 'dart:convert';
import 'dart:typed_data';

/// 메인 홈 / 베스트 리뷰 `bomiora_main_review` API 응답
class MainHomeReviewModel {
  final int mrNo;
  final String? itId;
  final String? mbId;
  final String? infId;
  final String? displayName;
  final bool isInfluencer;
  final double mrScore1;
  final double mrScore2;
  final double mrScore3;
  final double mrScore4;
  final double? averageScore;
  final String? mrTitle;
  final String? mrContent;
  final String? mrSummary;
  final String? productImage;
  final List<String> images;

  const MainHomeReviewModel({
    required this.mrNo,
    this.itId,
    this.mbId,
    this.infId,
    this.displayName,
    this.isInfluencer = false,
    this.mrScore1 = 0,
    this.mrScore2 = 0,
    this.mrScore3 = 0,
    this.mrScore4 = 0,
    this.averageScore,
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
    final s1 = _parseDouble(json['mrScore1']);
    final s2 = _parseDouble(json['mrScore2']);
    final s3 = _parseDouble(json['mrScore3']);
    final s4 = _parseDouble(json['mrScore4']);
    final avg = _parseDoubleNullable(json['averageScore']);
    return MainHomeReviewModel(
      mrNo: _parseInt(json['mrNo']),
      itId: _decodeTextField(json['itId']),
      mbId: _decodeTextField(json['mbId']),
      infId: _decodeTextField(json['infId']),
      displayName: _decodeTextField(json['displayName']),
      isInfluencer: json['isInfluencer'] == true ||
          (_decodeTextField(json['infId'])?.isNotEmpty ?? false),
      mrScore1: s1,
      mrScore2: s2,
      mrScore3: s3,
      mrScore4: s4,
      averageScore: avg,
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

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double? _parseDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String get reviewerName {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final inf = infId?.trim();
    if (inf != null && inf.isNotEmpty) return inf;
    return '리뷰어';
  }

  /// 홈 카드 본문 — `mr_title`
  String get cardTitleText {
    final t = mrTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '';
  }

  double get displayAverage => averageScore ?? 0;

  /// 카드 상단 한 줄 (제목 우선)
  String get headline {
    final t = mrTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '리뷰';
  }

  /// 카드 본문 요약 (`mr_summary` 우선)
  String get bodyText {
    final s = mrSummary?.trim();
    if (s != null && s.isNotEmpty) return s;
    final c = mrContent?.trim();
    if (c != null && c.isNotEmpty) return c;
    return '';
  }

  /// 펼침 시 본문 (content 우선)
  String get fullBodyText {
    final c = mrContent?.trim();
    if (c != null && c.isNotEmpty) return c;
    return bodyText;
  }
}

/// 베스트 리뷰 목록 전체 통계
class MainReviewStats {
  final int totalCount;
  final double averageScore;
  final int score1Percent;
  final int score2Percent;
  final int score3Percent;
  final int score4Percent;

  const MainReviewStats({
    this.totalCount = 0,
    this.averageScore = 0,
    this.score1Percent = 0,
    this.score2Percent = 0,
    this.score3Percent = 0,
    this.score4Percent = 0,
  });

  factory MainReviewStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MainReviewStats();
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    int i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return MainReviewStats(
      totalCount: i(json['totalCount']),
      averageScore: d(json['averageScore']),
      score1Percent: i(json['score1Percent']),
      score2Percent: i(json['score2Percent']),
      score3Percent: i(json['score3Percent']),
      score4Percent: i(json['score4Percent']),
    );
  }
}
