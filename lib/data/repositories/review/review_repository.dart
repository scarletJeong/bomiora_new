import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/review/review_model.dart';

class ReviewRepository {
  /// 제품의 리뷰 목록 가져오기
  /// 
  /// [productId] 제품 ID (it_id)
  /// [reviewKind] 리뷰 종류: 'general' (전체), 'supporter' (서포터), null (전체)
  static Future<List<ReviewModel>> getProductReviews({
    required String productId,
    String? reviewKind,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      print('🔍 리뷰 목록 조회 시작 - productId: $productId, reviewKind: $reviewKind');
      
      String endpoint = ApiEndpoints.productReviews;
      endpoint += '?it_id=$productId&page=$page&pageSize=$pageSize';
      
      if (reviewKind != null && reviewKind.isNotEmpty) {
        endpoint += '&is_rvkind=$reviewKind';
      }
      
      print('🌐 API 요청: ${ApiClient.baseUrl}$endpoint');
      
      final response = await ApiClient.get(endpoint);
      
      print('📡 응답 상태 코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 응답 구조에 따라 처리
        List<dynamic> reviews = [];
        if (data['success'] == true && data['data'] != null) {
          reviews = data['data'];
        } else if (data is List) {
          reviews = data;
        } else if (data['reviews'] != null) {
          reviews = data['reviews'];
        }
        
        print('✅ 리뷰 ${reviews.length}개 로드 완료');
        return reviews.map((json) => ReviewModel.fromJson(json)).toList();
      }
      
      print('⚠️ 리뷰 목록 조회 실패: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ 리뷰 목록 조회 오류: $e');
      return [];
    }
  }

  /// 리뷰 통계 가져오기 (평균 점수, 만족도 등)
  static Future<Map<String, dynamic>?> getReviewStats(String productId) async {
    try {
      final reviews = await getProductReviews(productId: productId);
      
      if (reviews.isEmpty) {
        return null;
      }
      
      // 서포터 리뷰만 필터링
      final supporterReviews = reviews.where((r) => r.isSupporterReview).toList();
      
      // 전체 평균 계산
      double totalAvg = 0;
      double supporterAvg = 0;
      
      if (reviews.isNotEmpty) {
        totalAvg = reviews
            .map((r) => r.averageScore ?? 0.0)
            .reduce((a, b) => a + b) / reviews.length;
      }
      
      if (supporterReviews.isNotEmpty) {
        supporterAvg = supporterReviews
            .map((r) => r.averageScore ?? 0.0)
            .reduce((a, b) => a + b) / supporterReviews.length;
      }
      
      // 만족도 계산 (is_recommend == 'y')
      final totalSatisfied = reviews.where((r) => r.isSatisfied).length;
      final supporterSatisfied = supporterReviews.where((r) => r.isSatisfied).length;
      
      // 카테고리별 평균 점수
      double score1Avg = 0; // 효과
      double score2Avg = 0; // 가성비
      double score3Avg = 0; // 향/맛
      double score4Avg = 0; // 편리함
      
      if (supporterReviews.isNotEmpty) {
        score1Avg = supporterReviews.map((r) => r.score1.toDouble()).reduce((a, b) => a + b) / supporterReviews.length;
        score2Avg = supporterReviews.map((r) => r.score2.toDouble()).reduce((a, b) => a + b) / supporterReviews.length;
        score3Avg = supporterReviews.map((r) => r.score3.toDouble()).reduce((a, b) => a + b) / supporterReviews.length;
        score4Avg = supporterReviews.map((r) => r.score4.toDouble()).reduce((a, b) => a + b) / supporterReviews.length;
      }
      
      return {
        'totalCount': reviews.length,
        'supporterCount': supporterReviews.length,
        'totalAverage': totalAvg,
        'supporterAverage': supporterAvg,
        'totalSatisfied': totalSatisfied,
        'supporterSatisfied': supporterSatisfied,
        'score1Avg': score1Avg, // 효과
        'score2Avg': score2Avg, // 가성비
        'score3Avg': score3Avg, // 향/맛
        'score4Avg': score4Avg, // 편리함
      };
    } catch (e) {
      print('❌ 리뷰 통계 조회 오류: $e');
      return null;
    }
  }
}

