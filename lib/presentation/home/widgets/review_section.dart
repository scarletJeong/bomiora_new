import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';

class ReviewSection extends StatelessWidget {
  const ReviewSection({super.key});

  static const List<Map<String, String>> _reviewItems = [
    {'name': 'test백주은 님', 'comment': 'test다이어트가 쫙 빠지고 얼굴라인이…'},
    {'name': '강희진testtes 님', 'comment': '다이어트 D-42 -16kg 감량하면서...'},
    {'name': '이소민 님', 'comment': 'test식단 조절만으로 이렇게 바뀔 수 있…'},
    {'name': '박서준 님', 'comment': 'test 운동이랑 병행하니까 속도가 확실…'},
    {'name': '최지우 님', 'comment': 'test 매일 아침 눈바디가 달라지는 경험!'},
    {'name': '정해인 님', 'comment': 'test 건강하게 살 빼고 싶은 분들께 강추…'},
    {'name': '임수향 님', 'comment': 'test 단백질 쉐이크 맛도 좋고 포만감 최고'},
    {'name': '유연석 님', 'comment': 'test testtesttesttest꾸준히 먹으니까 컨디션이 좋아졌…'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 2,
                    height: 40,
                    color: const Color(0xFF28171A),
                  ),
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BEST',
                        style: TextStyle(
                          color: Color(0x665B3F43),
                          fontSize: 10,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '리뷰',
                        style: TextStyle(
                          color: Color(0xFF28171A),
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: ShapeDecoration(
                  color: const Color(0xFFFF5A8D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: const Text(
                  '+ More',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 0),
          Transform.translate(
            offset: const Offset(0, -35),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 185,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _reviewItems.length,
              itemBuilder: (context, index) {
                return _ReviewCard(
                  name: _reviewItems[index]['name']!,
                  comment: _reviewItems[index]['comment']!,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFE0E0E0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFFF5A8D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: const Text(
                    '리뷰 더보기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFE0E0E0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  /// 1에 가까울수록 오버레이가 진해지고 뒤 리뷰 이미지는 덜 비칩니다.
  static const double _overlayOpacity = 0.9;

  /// 오버레이 PNG를 살짝 아래로 내려 하단 곡선이 더 낮게 보이도록
  static const Offset _overlayNudge = Offset(0, 20);

  final String name;
  final String comment;

  const _ReviewCard({
    required this.name,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // TODO: 실제 리뷰 썸네일(Image.network 등)로 교체 — 현재는 시연용 회색 배경
          Positioned.fill(
            child: Container(
              color: const Color(0xFFE0E0E0),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: _overlayOpacity,
              child: Transform.translate(
                offset: _overlayNudge,
                child: Image.asset(
                  AppAssets.reviewCardOverlay,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 2,
                        height: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Color(0x66000000),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Color(0x66000000),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
