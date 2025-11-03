class Review {
  final int id;
  final String productId; // it_id
  final String userId; // mb_id
  final String userName; // is_name
  final String reviewType; // is_gubun: 'P' or 'G'
  final int score1; // 효과
  final int score2; // 가성비
  final int score3; // 향/맛
  final int score4; // 편리함
  final String subject; // is_subject
  final String content; // is_content
  final int helpfulCount; // is_good (도움수)
  final DateTime createdAt; // is_time
  final DateTime updatedAt; // is_update_time
  final int confirmStatus; // is_confirm
  final String purchaseMethod; // is_pay_mthod: 'solo' or 'group'
  final String weightLoss; // is_outage_num (감량체중)
  final String negativeText; // is_negative_review_text
  final String positiveText; // is_positive_review_text
  final String tipText; // is_more_review_text
  final String recommend; // is_recommend: 'y' or 'n'
  final bool isDirectUse; // is_rv_check
  final String reviewKind; // is_rvkind: 'general' or 'supporter'
  final String birthday; // is_birthday
  final String height; // is_height
  final String weight; // is_weight
  final List<String> images; // is_img1 ~ is_img10

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.reviewType,
    required this.score1,
    required this.score2,
    required this.score3,
    required this.score4,
    required this.subject,
    required this.content,
    required this.helpfulCount,
    required this.createdAt,
    required this.updatedAt,
    required this.confirmStatus,
    required this.purchaseMethod,
    required this.weightLoss,
    required this.negativeText,
    required this.positiveText,
    required this.tipText,
    required this.recommend,
    required this.isDirectUse,
    required this.reviewKind,
    required this.birthday,
    required this.height,
    required this.weight,
    required this.images,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // 이미지 리스트 생성 (is_img1 ~ is_img10)
    final images = <String>[];
    for (int i = 1; i <= 10; i++) {
      final imgKey = 'is_img$i';
      final imgUrl = json[imgKey]?.toString();
      if (imgUrl != null && imgUrl.isNotEmpty) {
        images.add(imgUrl);
      }
    }

    return Review(
      id: json['is_id'] ?? 0,
      productId: json['it_id']?.toString() ?? '',
      userId: json['mb_id']?.toString() ?? '',
      userName: json['is_name']?.toString() ?? '',
      reviewType: json['is_gubun']?.toString() ?? 'G',
      score1: json['is_score1'] ?? 0,
      score2: json['is_score2'] ?? 0,
      score3: json['is_score3'] ?? 0,
      score4: json['is_score4'] ?? 0,
      subject: json['is_subject']?.toString() ?? '',
      content: json['is_content']?.toString() ?? '',
      helpfulCount: json['is_good'] ?? 0,
      createdAt: json['is_time'] != null
          ? DateTime.parse(json['is_time'].toString())
          : DateTime.now(),
      updatedAt: json['is_update_time'] != null
          ? DateTime.parse(json['is_update_time'].toString())
          : DateTime.now(),
      confirmStatus: json['is_confirm'] ?? 0,
      purchaseMethod: json['is_pay_mthod']?.toString() ?? 'solo',
      weightLoss: json['is_outage_num']?.toString() ?? '0',
      negativeText: json['is_negative_review_text']?.toString() ?? '',
      positiveText: json['is_positive_review_text']?.toString() ?? '',
      tipText: json['is_more_review_text']?.toString() ?? '',
      recommend: json['is_recommend']?.toString() ?? 'n',
      isDirectUse: (json['is_rv_check'] ?? 0) == 1,
      reviewKind: json['is_rvkind']?.toString() ?? 'general',
      birthday: json['is_birthday']?.toString() ?? '',
      height: json['is_height']?.toString() ?? '',
      weight: json['is_weight']?.toString() ?? '',
      images: images,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_id': id,
      'it_id': productId,
      'mb_id': userId,
      'is_name': userName,
      'is_gubun': reviewType,
      'is_score1': score1,
      'is_score2': score2,
      'is_score3': score3,
      'is_score4': score4,
      'is_subject': subject,
      'is_content': content,
      'is_good': helpfulCount,
      'is_time': createdAt.toIso8601String(),
      'is_update_time': updatedAt.toIso8601String(),
      'is_confirm': confirmStatus,
      'is_pay_mthod': purchaseMethod,
      'is_outage_num': weightLoss,
      'is_negative_review_text': negativeText,
      'is_positive_review_text': positiveText,
      'is_more_review_text': tipText,
      'is_recommend': recommend,
      'is_rv_check': isDirectUse ? 1 : 0,
      'is_rvkind': reviewKind,
      'is_birthday': birthday,
      'is_height': height,
      'is_weight': weight,
    };
  }

  // 전체 평균 점수 계산
  double get averageScore {
    final scores = [score1, score2, score3, score4].where((s) => s > 0).toList();
    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  // 별점 (5점 만점)
  double get rating {
    return averageScore;
  }

  // 만족 여부 (is_recommend가 'y'인 경우)
  bool get isSatisfied {
    return recommend == 'y';
  }

  // 서포터 리뷰 여부
  bool get isSupporterReview {
    return reviewKind == 'supporter';
  }

  // 일반 리뷰 여부
  bool get isGeneralReview {
    return reviewKind == 'general';
  }
}

