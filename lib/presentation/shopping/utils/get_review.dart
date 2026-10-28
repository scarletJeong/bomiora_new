import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';

class ProductReviewLoadResult {
  final List<ReviewModel> allReviews;
  final List<ReviewModel> supporterReviews;
  final List<ReviewModel> generalReviews;
  final Map<String, dynamic> stats;

  const ProductReviewLoadResult({
    required this.allReviews,
    required this.supporterReviews,
    required this.generalReviews,
    required this.stats,
  });
}

class ProductReviewLoader {
  static final Map<String, ProductReviewLoadResult> _memory = {};
  static final Map<String, Future<ProductReviewLoadResult?>> _inflight = {};

  /// 같은 상품을 다시 열면 네트워크 전에 바로 그릴 수 있게 한다.
  static ProductReviewLoadResult? cached(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    return _memory[id];
  }

  static Future<ProductReviewLoadResult?> load({
    required String productId,
  }) {
    final id = productId.trim();
    if (id.isEmpty) return Future.value(null);
    final pending = _inflight[id];
    if (pending != null) return pending;

    late final Future<ProductReviewLoadResult?> future;
    future = _fetch(productId: id).then((result) {
      if (result != null) _memory[id] = result;
      return result;
    }).whenComplete(() {
      if (identical(_inflight[id], future)) {
        _inflight.remove(id);
      }
    });
    _inflight[id] = future;
    return future;
  }

  static Future<ProductReviewLoadResult?> _fetch({
    required String productId,
  }) async {

    // 리뷰 통합(it_review_link)은 서버가 상품 번호 기준으로 풀어 준다.
    final allReviews = await _fetchAllPages(productId);
    if (allReviews == null) return null;
    final supporter = allReviews.where((r) => r.isSupporterReview).toList();
    // 카페24 '전체 리뷰'와 같음. 서포터를 뺀 목록이 아니다.
    final general = allReviews;

    final stats = _buildStats(allReviews: allReviews, supporter: supporter);
    return ProductReviewLoadResult(
      allReviews: allReviews,
      supporterReviews: supporter,
      generalReviews: general,
      stats: stats,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// 승인 리뷰를 페이지마다 이어서 모두 받는다. 한 페이지 상한은 200건이다.
  static Future<List<ReviewModel>?> _fetchAllPages(String itId) async {
    const size = 200;
    final first = await ReviewService.getProductReviews(
      itId: itId,
      rvkind: null,
      page: 0,
      size: size,
    );
    if (first['success'] != true) return null;

    final reviews = List<ReviewModel>.from(
      first['reviews'] as List<ReviewModel>? ?? const [],
    );
    final total = _asInt(first['totalElements']);
    var page = 1;
    while (reviews.length < total && page < 30) {
      final next = await ReviewService.getProductReviews(
        itId: itId,
        rvkind: null,
        page: page,
        size: size,
      );
      if (next['success'] != true) break;
      final batch = List<ReviewModel>.from(
        next['reviews'] as List<ReviewModel>? ?? const [],
      );
      if (batch.isEmpty) break;
      reviews.addAll(batch);
      page += 1;
    }
    return reviews;
  }

  static Map<String, dynamic> _buildStats({
    required List<ReviewModel> allReviews,
    required List<ReviewModel> supporter,
  }) {
    double totalAverage = 0.0;
    double supporterAverage = 0.0;
    int totalSatisfied = 0;
    int supporterSatisfied = 0;
    double score1Avg = 0.0;
    double score2Avg = 0.0;
    double score3Avg = 0.0;
    double score4Avg = 0.0;
    double totalScore1Avg = 0.0;
    double totalScore2Avg = 0.0;
    double totalScore3Avg = 0.0;
    double totalScore4Avg = 0.0;

    final reviewsWithScore =
        allReviews.where((r) => r.averageScore != null).toList();
    if (reviewsWithScore.isNotEmpty) {
      totalAverage =
          reviewsWithScore.map((r) => r.averageScore!).reduce((a, b) => a + b) /
              reviewsWithScore.length;
      totalSatisfied = allReviews.where((r) => r.isSatisfied).length;
      if (allReviews.isNotEmpty) {
        totalScore1Avg =
            allReviews.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) /
                allReviews.length;
        totalScore2Avg =
            allReviews.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) /
                allReviews.length;
        totalScore3Avg =
            allReviews.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) /
                allReviews.length;
        totalScore4Avg =
            allReviews.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) /
                allReviews.length;
      }
    }

    final supporterWithScore =
        supporter.where((r) => r.averageScore != null).toList();
    if (supporterWithScore.isNotEmpty) {
      supporterAverage = supporterWithScore
              .map((r) => r.averageScore!)
              .reduce((a, b) => a + b) /
          supporterWithScore.length;
      supporterSatisfied = supporter.where((r) => r.isSatisfied).length;
      if (supporter.isNotEmpty) {
        score1Avg =
            supporter.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) /
                supporter.length;
        score2Avg =
            supporter.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) /
                supporter.length;
        score3Avg =
            supporter.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) /
                supporter.length;
        score4Avg =
            supporter.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) /
                supporter.length;
      }
    }

    return {
      'totalCount': allReviews.length,
      'totalAverage': totalAverage,
      'supporterAverage': supporterAverage,
      'totalSatisfied': totalSatisfied,
      'supporterSatisfied': supporterSatisfied,
      'score1Avg': score1Avg,
      'score2Avg': score2Avg,
      'score3Avg': score3Avg,
      'score4Avg': score4Avg,
      'totalScore1Avg': totalScore1Avg,
      'totalScore2Avg': totalScore2Avg,
      'totalScore3Avg': totalScore3Avg,
      'totalScore4Avg': totalScore4Avg,
    };
  }
}
