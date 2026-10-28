import '../../../data/models/review/review_model.dart';
import '../../../data/services/review_service.dart';

class ProductReviewLoadResult {
  final List<ReviewModel> allReviews;
  final List<ReviewModel> supporterReviews;
  final List<ReviewModel> generalReviews;
  final Map<String, dynamic> stats;
  final bool supporterHasNext;
  final bool allHasNext;

  const ProductReviewLoadResult({
    required this.allReviews,
    required this.supporterReviews,
    required this.generalReviews,
    required this.stats,
    required this.supporterHasNext,
    required this.allHasNext,
  });
}

class ProductReviewPage {
  final List<ReviewModel> reviews;
  final bool hasNext;
  final int totalCount;

  const ProductReviewPage({
    required this.reviews,
    required this.hasNext,
    required this.totalCount,
  });
}

/// 탭에 찍는 갯수. 리뷰 본문과 따로 받는다.
class ProductReviewCounts {
  final int totalCount;
  final int supporterCount;
  final double? totalAverage;
  final double? supporterAverage;
  final double? totalScore1;
  final double? totalScore2;
  final double? totalScore3;
  final double? totalScore4;
  final double? supporterScore1;
  final double? supporterScore2;
  final double? supporterScore3;
  final double? supporterScore4;

  const ProductReviewCounts({
    required this.totalCount,
    required this.supporterCount,
    this.totalAverage,
    this.supporterAverage,
    this.totalScore1,
    this.totalScore2,
    this.totalScore3,
    this.totalScore4,
    this.supporterScore1,
    this.supporterScore2,
    this.supporterScore3,
    this.supporterScore4,
  });

  factory ProductReviewCounts.fromStats(ReviewStatsModel stats) {
    return ProductReviewCounts(
      totalCount: stats.totalCount,
      supporterCount: stats.supporterCount ?? 0,
      totalAverage: stats.averageScore,
      supporterAverage: stats.supporterAverage,
      totalScore1: stats.score1Avg,
      totalScore2: stats.score2Avg,
      totalScore3: stats.score3Avg,
      totalScore4: stats.score4Avg,
      supporterScore1: stats.supporterScore1Avg,
      supporterScore2: stats.supporterScore2Avg,
      supporterScore3: stats.supporterScore3Avg,
      supporterScore4: stats.supporterScore4Avg,
    );
  }
}

class ProductReviewLoader {
  static const int pageSize = 12;

  static final Map<String, ProductReviewLoadResult> _memory = {};
  static final Map<String, Future<ProductReviewLoadResult?>> _inflight = {};
  static final Map<String, ProductReviewCounts> _counts = {};
  static final Map<String, Future<ProductReviewCounts?>> _countInflight = {};

  /// 같은 상품을 다시 열면 네트워크 전에 바로 그릴 수 있게 한다.
  static ProductReviewLoadResult? cached(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    return _memory[id];
  }

  static ProductReviewCounts? cachedCounts(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    return _counts[id];
  }

  /// 서포터/전체 갯수만 받는다. 리뷰 본문을 기다리지 않는다.
  static Future<ProductReviewCounts?> loadCounts(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return Future.value(null);
    final pending = _countInflight[id];
    if (pending != null) return pending;

    late final Future<ProductReviewCounts?> future;
    future = _fetchCounts(id).then((result) {
      if (result != null) _counts[id] = result;
      return result;
    }).whenComplete(() {
      if (identical(_countInflight[id], future)) {
        _countInflight.remove(id);
      }
    });
    _countInflight[id] = future;
    return future;
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

  static Future<ProductReviewCounts?> _fetchCounts(String productId) async {
    final result = await ReviewService.getProductReviewStats(itId: productId);
    final stats = result['stats'] as ReviewStatsModel?;
    if (result['success'] == true && stats != null && stats.supporterCount != null) {
      return ProductReviewCounts.fromStats(stats);
    }

    if (result['success'] == true && stats != null) {
      final supporterPage = await fetchPage(
        productId: productId,
        rvkind: 'supporter',
        page: 0,
        size: 1,
      );
      return ProductReviewCounts(
        totalCount: stats.totalCount,
        supporterCount: supporterPage == null
            ? 0
            : _asInt(supporterPage.totalCount),
      );
    }

    final pages = await Future.wait([
      fetchPage(productId: productId, page: 0, size: 1),
      fetchPage(productId: productId, rvkind: 'supporter', page: 0, size: 1),
    ]);
    final all = pages[0];
    if (all == null) return null;
    return ProductReviewCounts(
      totalCount: all.totalCount,
      supporterCount: pages[1]?.totalCount ?? 0,
    );
  }

  static Future<ProductReviewLoadResult?> _fetch({
    required String productId,
  }) async {
    final pages = await Future.wait([
      fetchPage(productId: productId, page: 0),
      fetchPage(productId: productId, rvkind: 'supporter', page: 0),
    ]);
    final all = pages[0];
    final supporter = pages[1];
    if (all == null && supporter == null) return null;

    final allReviews = all?.reviews ?? const <ReviewModel>[];
    final supporterReviews = supporter?.reviews ?? const <ReviewModel>[];
    return ProductReviewLoadResult(
      allReviews: allReviews,
      supporterReviews: supporterReviews,
      generalReviews: allReviews,
      supporterHasNext: supporter?.hasNext ?? false,
      allHasNext: all?.hasNext ?? false,
      stats: _buildStats(allReviews: allReviews, supporter: supporterReviews),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// 한 페이지만 받는다. 더보기는 다음 페이지를 이어서 요청한다.
  static Future<ProductReviewPage?> fetchPage({
    required String productId,
    String? rvkind,
    required int page,
    int size = pageSize,
  }) async {
    final result = await ReviewService.getProductReviews(
      itId: productId,
      rvkind: rvkind,
      page: page,
      size: size,
    );
    if (result['success'] != true) return null;
    return ProductReviewPage(
      reviews: List<ReviewModel>.from(
        result['reviews'] as List<ReviewModel>? ?? const [],
      ),
      hasNext: result['hasNext'] == true,
      totalCount: _asInt(result['totalElements']),
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
