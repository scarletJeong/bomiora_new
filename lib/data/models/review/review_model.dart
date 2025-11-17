/// 리뷰 모델
class ReviewModel {
  final int? isId;
  final String itId;
  final String? itName; // 제품명
  final String mbId;
  final String? isName;
  final DateTime? isTime;
  final int? isConfirm;
  
  // 평점 (각 5점 만점)
  final int isScore1; // 효과
  final int isScore2; // 가성비
  final int isScore3; // 맛/향
  final int isScore4; // 편리함
  final double? averageScore; // 평균 평점
  
  // 리뷰 종류
  final String isRvkind; // 'general' or 'supporter'
  
  // 추천 여부
  final String isRecommend; // 'y' or 'n'
  final int? isGood; // 도움이 돼요 카운트
  final int? czDownload; // 도움쿠폰 다운로드 카운트
  
  // 리뷰 내용
  final String? isPositiveReviewText; // 좋았던 점
  final String? isNegativeReviewText; // 아쉬운 점
  final String? isMoreReviewText; // 꿀팁
  
  // 이미지들
  final List<String> images;
  
  // 사용자 정보
  final DateTime? isBirthday;
  final int? isWeight;
  final int? isHeight;
  final String? isPayMthod; // 'solo': 내돈내산
  final int? isOutageNum; // 감량 kg
  
  final int? odId; // 주문 ID
  
  // 편의 getter들
  bool get isSupporterReview => isRvkind == 'supporter';
  bool get isGeneralReview => isRvkind == 'general';
  bool get isSatisfied => isRecommend == 'y';
  int get score1 => isScore1;
  int get score2 => isScore2;
  int get score3 => isScore3;
  int get score4 => isScore4;
  
  ReviewModel({
    this.isId,
    required this.itId,
    this.itName,
    required this.mbId,
    this.isName,
    this.isTime,
    this.isConfirm,
    required this.isScore1,
    required this.isScore2,
    required this.isScore3,
    required this.isScore4,
    this.averageScore,
    required this.isRvkind,
    required this.isRecommend,
    this.isGood,
    this.czDownload,
    this.isPositiveReviewText,
    this.isNegativeReviewText,
    this.isMoreReviewText,
    this.images = const [],
    this.isBirthday,
    this.isWeight,
    this.isHeight,
    this.isPayMthod,
    this.isOutageNum,
    this.odId,
  });
  
  /// JSON에서 모델로 변환
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    List<String> imageList = [];
    if (json['images'] != null) {
      imageList = List<String>.from(json['images']);
    }
    
    return ReviewModel(
      isId: json['isId'],
      itId: json['itId'] ?? '',
      itName: json['itName'],
      mbId: json['mbId'] ?? '',
      isName: json['isName'],
      isTime: json['isTime'] != null ? DateTime.parse(json['isTime']) : null,
      isConfirm: json['isConfirm'],
      isScore1: json['isScore1'] ?? 0,
      isScore2: json['isScore2'] ?? 0,
      isScore3: json['isScore3'] ?? 0,
      isScore4: json['isScore4'] ?? 0,
      averageScore: json['averageScore']?.toDouble(),
      isRvkind: json['isRvkind'] ?? 'general',
      isRecommend: json['isRecommend'] ?? 'y',
      isGood: json['isGood'] ?? 0,
      czDownload: json['czDownload'] ?? 0,
      isPositiveReviewText: json['isPositiveReviewText'],
      isNegativeReviewText: json['isNegativeReviewText'],
      isMoreReviewText: json['isMoreReviewText'],
      images: imageList,
      isBirthday: json['isBirthday'] != null ? DateTime.parse(json['isBirthday']) : null,
      isWeight: json['isWeight'],
      isHeight: json['isHeight'],
      isPayMthod: json['isPayMthod'],
      isOutageNum: json['isOutageNum'],
      odId: json['odId'],
    );
  }
  
  /// 모델에서 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (isId != null) 'isId': isId,
      'itId': itId,
      if (itName != null) 'itName': itName,
      'mbId': mbId,
      if (isName != null) 'isName': isName,
      if (isTime != null) 'isTime': isTime!.toIso8601String(),
      if (isConfirm != null) 'isConfirm': isConfirm,
      'isScore1': isScore1,
      'isScore2': isScore2,
      'isScore3': isScore3,
      'isScore4': isScore4,
      if (averageScore != null) 'averageScore': averageScore,
      'isRvkind': isRvkind,
      'isRecommend': isRecommend,
      if (isGood != null) 'isGood': isGood,
      if (czDownload != null) 'czDownload': czDownload,
      if (isPositiveReviewText != null) 'isPositiveReviewText': isPositiveReviewText,
      if (isNegativeReviewText != null) 'isNegativeReviewText': isNegativeReviewText,
      if (isMoreReviewText != null) 'isMoreReviewText': isMoreReviewText,
      'images': images,
      if (isBirthday != null) 'isBirthday': isBirthday!.toIso8601String().split('T')[0],
      if (isWeight != null) 'isWeight': isWeight,
      if (isHeight != null) 'isHeight': isHeight,
      if (isPayMthod != null) 'isPayMthod': isPayMthod,
      if (isOutageNum != null) 'isOutageNum': isOutageNum,
      if (odId != null) 'odId': odId,
    };
  }
}

/// 리뷰 통계 모델
class ReviewStatsModel {
  final int totalCount;
  final double averageScore;
  final int? generalCount;
  final int? supporterCount;
  
  ReviewStatsModel({
    required this.totalCount,
    required this.averageScore,
    this.generalCount,
    this.supporterCount,
  });
  
  factory ReviewStatsModel.fromJson(Map<String, dynamic> json) {
    return ReviewStatsModel(
      totalCount: json['totalCount'] ?? 0,
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
      generalCount: json['generalCount'],
      supporterCount: json['supporterCount'],
    );
  }
}
