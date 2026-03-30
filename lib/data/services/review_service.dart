import 'dart:convert';
import '../models/review/review_model.dart';
import '../../core/network/api_client.dart';

// 리뷰 서비스 내부 디버그 콘솔 출력 비활성화
void print(Object? object) {}

/// 리뷰 서비스
class ReviewService {
  /// 리뷰 작성
  /// 
  /// [reviewData] 리뷰 데이터
  static Future<Map<String, dynamic>> createReview(ReviewModel reviewData) async {
    try {
      print('✍️ [리뷰 작성] 요청');
      print('  - itId: ${reviewData.itId}');
      print('  - mbId: ${reviewData.mbId}');
      print('  - odId: ${reviewData.odId}');

      final response = await ApiClient.post(
        '/api/user/reviews',
        reviewData.toJson(),
      );

      print('📡 [리뷰 작성] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [리뷰 작성] 성공: ${data['message']}');
        
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '리뷰가 성공적으로 작성되었습니다.',
          'review': data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [리뷰 작성] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 작성에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [리뷰 작성] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 작성 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 전체 리뷰 목록 조회 (모든 상품의 리뷰)
  /// 
  /// [rvkind] 리뷰 종류 ('general', 'supporter', null=전체)
  /// [page] 페이지 번호 (0부터 시작)
  /// [size] 페이지 크기
  static Future<Map<String, dynamic>> getAllReviews({
    String? rvkind,
    int page = 0,
    int size = 20,
  }) async {
    try {
      print('📖 [전체 리뷰 목록 조회] 요청');
      print('  - rvkind: $rvkind');
      print('  - page: $page, size: $size');

      // 쿼리 파라미터 구성
      String queryString = 'page=$page&size=$size';
      if (rvkind != null && rvkind.isNotEmpty) {
        queryString += '&rvkind=$rvkind';
      }
      
      final response = await ApiClient.get(
        '/api/user/reviews?$queryString',
      );

      print('📡 [전체 리뷰 목록 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 리뷰 목록 파싱
        List<ReviewModel> reviews = [];
        if (data['reviews'] != null) {
          reviews = (data['reviews'] as List)
              .map((review) => ReviewModel.fromJson(review))
              .toList();
        }
        
        print('✅ [전체 리뷰 목록 조회] 성공: ${reviews.length}개');
        
        return {
          'success': true,
          'reviews': reviews,
          'currentPage': data['currentPage'] ?? 0,
          'totalPages': data['totalPages'] ?? 0,
          'totalElements': data['totalElements'] ?? 0,
          'hasNext': data['hasNext'] ?? false,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [전체 리뷰 목록 조회] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 목록을 불러올 수 없습니다.',
          'reviews': <ReviewModel>[],
        };
      }
    } catch (e) {
      print('❌ [전체 리뷰 목록 조회] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 목록 조회 중 오류가 발생했습니다: $e',
        'reviews': <ReviewModel>[],
      };
    }
  }
  
  /// 특정 상품의 리뷰 목록 조회
  /// 
  /// [itId] 상품 ID
  /// [rvkind] 리뷰 종류 ('general', 'supporter', null=전체)
  /// [page] 페이지 번호 (0부터 시작)
  /// [size] 페이지 크기
  static Future<Map<String, dynamic>> getProductReviews({
    required String itId,
    String? rvkind,
    int page = 0,
    int size = 20,
  }) async {
    try {
      print('📖 [상품 리뷰 목록 조회] 요청');
      print('  - itId: $itId');
      print('  - rvkind: $rvkind');
      print('  - page: $page, size: $size');

      // 쿼리 파라미터 구성 (rvkind만 사용)
      String queryString = 'page=$page&size=$size';
      if (rvkind != null && rvkind.isNotEmpty) {
        queryString += '&rvkind=$rvkind';
      }
      
      final response = await ApiClient.get(
        '/api/user/reviews/product/$itId?$queryString',
      );

      print('📡 [상품 리뷰 목록 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 리뷰 목록 파싱
        List<ReviewModel> reviews = [];
        if (data['reviews'] != null) {
          reviews = (data['reviews'] as List)
              .map((review) => ReviewModel.fromJson(review))
              .toList();
        }
        
        print('✅ [상품 리뷰 목록 조회] 성공: ${reviews.length}개');
        
        return {
          'success': true,
          'reviews': reviews,
          'currentPage': data['currentPage'] ?? 0,
          'totalPages': data['totalPages'] ?? 0,
          'totalElements': data['totalElements'] ?? 0,
          'hasNext': data['hasNext'] ?? false,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [상품 리뷰 목록 조회] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 목록을 불러올 수 없습니다.',
          'reviews': <ReviewModel>[],
        };
      }
    } catch (e) {
      print('❌ [상품 리뷰 목록 조회] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 목록 조회 중 오류가 발생했습니다: $e',
        'reviews': <ReviewModel>[],
      };
    }
  }
  
  /// 특정 회원의 리뷰 목록 조회
  /// 
  /// [mbId] 회원 ID
  /// [page] 페이지 번호 (0부터 시작)
  /// [size] 페이지 크기
  static Future<Map<String, dynamic>> getMemberReviews({
    required String mbId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      print('📖 [회원 리뷰 목록 조회] 요청');
      print('  - mbId: $mbId');
      print('  - page: $page, size: $size');

      final queryString = 'page=$page&size=$size';
      
      final response = await ApiClient.get(
        '/api/user/reviews/member/$mbId?$queryString',
      );

      print('📡 [회원 리뷰 목록 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 리뷰 목록 파싱
        List<ReviewModel> reviews = [];
        if (data['reviews'] != null) {
          reviews = (data['reviews'] as List)
              .map((review) => ReviewModel.fromJson(review))
              .toList();
        }
        
        print('✅ [회원 리뷰 목록 조회] 성공: ${reviews.length}개');
        
        return {
          'success': true,
          'reviews': reviews,
          'currentPage': data['currentPage'] ?? 0,
          'totalPages': data['totalPages'] ?? 0,
          'totalElements': data['totalElements'] ?? 0,
          'hasNext': data['hasNext'] ?? false,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [회원 리뷰 목록 조회] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 목록을 불러올 수 없습니다.',
          'reviews': <ReviewModel>[],
        };
      }
    } catch (e) {
      print('❌ [회원 리뷰 목록 조회] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 목록 조회 중 오류가 발생했습니다: $e',
        'reviews': <ReviewModel>[],
      };
    }
  }
  
  /// 상품 리뷰 통계 조회
  /// 
  /// [itId] 상품 ID
  static Future<Map<String, dynamic>> getProductReviewStats({
    required String itId,
  }) async {
    try {
      print('📊 [상품 리뷰 통계 조회] 요청');
      print('  - itId: $itId');
      
      final response = await ApiClient.get(
        '/api/user/reviews/product/$itId/stats',
      );

      print('📡 [상품 리뷰 통계 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [상품 리뷰 통계 조회] 성공');
        
        return {
          'success': true,
          'stats': data['stats'] != null 
              ? ReviewStatsModel.fromJson(data['stats']) 
              : null,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [상품 리뷰 통계 조회] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 통계를 불러올 수 없습니다.',
        };
      }
    } catch (e) {
      print('❌ [상품 리뷰 통계 조회] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 통계 조회 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 리뷰 상세 조회
  /// 
  /// [isId] 리뷰 ID
  static Future<Map<String, dynamic>> getReviewById(int isId) async {
    try {
      print('📖 [리뷰 상세 조회] 요청');
      print('  - isId: $isId');
      
      final response = await ApiClient.get(
        '/api/user/reviews/$isId',
      );

      print('📡 [리뷰 상세 조회] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [리뷰 상세 조회] 성공');
        
        return {
          'success': true,
          'review': data['review'] != null 
              ? ReviewModel.fromJson(data['review']) 
              : null,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [리뷰 상세 조회] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰를 불러올 수 없습니다.',
        };
      }
    } catch (e) {
      print('❌ [리뷰 상세 조회] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 조회 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 리뷰 수정
  /// 
  /// [isId] 리뷰 ID
  /// [reviewData] 수정할 리뷰 데이터
  static Future<Map<String, dynamic>> updateReview(int isId, ReviewModel reviewData) async {
    try {
      print('✏️ [리뷰 수정] 요청');
      print('  - isId: $isId');
      
      final response = await ApiClient.put(
        '/api/user/reviews/$isId',
        reviewData.toJson(),
      );

      print('📡 [리뷰 수정] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [리뷰 수정] 성공: ${data['message']}');
        
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '리뷰가 성공적으로 수정되었습니다.',
          'review': data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [리뷰 수정] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 수정에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [리뷰 수정] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 수정 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 리뷰 삭제
  /// 
  /// [isId] 리뷰 ID
  /// [mbId] 회원 ID (권한 확인용)
  static Future<Map<String, dynamic>> deleteReview(int isId, String mbId) async {
    try {
      print('🗑️ [리뷰 삭제] 요청');
      print('  - isId: $isId');
      print('  - mbId: $mbId');
      
      final response = await ApiClient.delete(
        '/api/user/reviews/$isId?mbId=$mbId',
      );

      print('📡 [리뷰 삭제] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [리뷰 삭제] 성공: ${data['message']}');
        
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '리뷰가 성공적으로 삭제되었습니다.',
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [리뷰 삭제] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '리뷰 삭제에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [리뷰 삭제] 오류: $e');
      return {
        'success': false,
        'message': '리뷰 삭제 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 리뷰 도움됨 증가
  /// 
  /// [isId] 리뷰 ID
  /// [mbId] 회원 ID
  static Future<Map<String, dynamic>> incrementReviewHelpful(int isId, String mbId) async {
    try {
      print('👍 [리뷰 도움됨 증가] 요청');
      print('  - isId: $isId');
      print('  - mbId: $mbId');
      
      final response = await ApiClient.post(
        '/api/user/reviews/$isId/helpful',
        {'mbId': mbId},
      );

      print('📡 [리뷰 도움됨 증가] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [리뷰 도움됨 증가] 성공');
        
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? '도움이 돼요가 증가했습니다.',
          'isGood': data['isGood'],
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [리뷰 도움됨 증가] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '처리에 실패했습니다.',
        };
      }
    } catch (e) {
      print('❌ [리뷰 도움됨 증가] 오류: $e');
      return {
        'success': false,
        'message': '처리 중 오류가 발생했습니다: $e',
      };
    }
  }
  
  /// 주문에 대한 리뷰 작성 여부 확인
  /// 
  /// [mbId] 회원 ID
  /// [odId] 주문 ID (String - 큰 숫자 정밀도 손실 방지)
  static Future<Map<String, dynamic>> checkReviewExists({
    required String mbId,
    required String odId,
  }) async {
    try {
      print('🔍 [리뷰 존재 확인] 요청');
      print('  - mbId: $mbId');
      print('  - odId: $odId');
      
      final queryString = 'mbId=$mbId&odId=$odId';
      
      final response = await ApiClient.get(
        '/api/user/reviews/check?$queryString',
      );

      print('📡 [리뷰 존재 확인] 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('✅ [리뷰 존재 확인] 성공: exists=${data['exists']}');
        
        return {
          'success': true,
          'exists': data['exists'] ?? false,
        };
      } else {
        final errorData = json.decode(response.body);
        print('❌ [리뷰 존재 확인] 실패: ${errorData['message']}');
        
        return {
          'success': false,
          'message': errorData['message'] ?? '확인에 실패했습니다.',
          'exists': false,
        };
      }
    } catch (e) {
      print('❌ [리뷰 존재 확인] 오류: $e');
      return {
        'success': false,
        'message': '확인 중 오류가 발생했습니다: $e',
        'exists': false,
      };
    }
  }
}

