import '../../../core/utils/node_value_parser.dart';
import '../../../data/models/product/product_model.dart';
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
    Product? product,
  }) {
    final id = productId.trim();
    if (id.isEmpty) return Future.value(null);
    final pending = _inflight[id];
    if (pending != null) return pending;

    late final Future<ProductReviewLoadResult?> future;
    future = _fetch(productId: id, product: product).then((result) {
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
    Product? product,
  }) async {

    String reviewProductId = productId;
    if (product?.additionalInfo != null) {
      final itOrgId =
          NodeValueParser.asString(product!.additionalInfo!['it_org_id']) ??
              NodeValueParser.asString(product.additionalInfo!['itOrgId']);
      if (itOrgId != null && itOrgId.isNotEmpty) {
        reviewProductId = itOrgId;
      }
    }

    final result = await ReviewService.getProductReviews(
      itId: reviewProductId,
      rvkind: null,
      page: 0,
      size: 24,
      fetchAll: false,
    );

    if (result['success'] != true) {
      return null;
    }

    final allReviews = result['reviews'] as List<ReviewModel>;
    final supporter = allReviews.where((r) => r.isSupporterReview).toList();
    // 일반 리뷰 탭은 서포터가 아닌 리뷰. 구매 리뷰(is_rvkind=prescription)도 포함한다.
    final general = allReviews.where((r) => !r.isSupporterReview).toList();

    final stats = _buildStats(allReviews: allReviews, supporter: supporter);
    return ProductReviewLoadResult(
      allReviews: allReviews,
      supporterReviews: supporter,
      generalReviews: general,
      stats: stats,
    );
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
