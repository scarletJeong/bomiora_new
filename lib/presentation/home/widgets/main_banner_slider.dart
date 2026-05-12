import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

class MainBannerSlider extends StatefulWidget {
  const MainBannerSlider({super.key});

  @override
  State<MainBannerSlider> createState() => _MainBannerSliderState();
}

class _MainBannerSliderState extends State<MainBannerSlider> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<BannerItem> banners = [
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '보미오라 다이어트',
      subtitle: '건강한 체중감량의 시작',
      productId: '1686290723',
    ),
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '다이어트 왜 자꾸 실패할까요?',
      subtitle: '공중파, 종편 TV출연 몸짱 한의사 다이어트',
    ),
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '다이어트환/디톡스환 특허 등록',
      subtitle: '정대진 대표원장이 연구 배합,개발 후 특허등록',
    ),
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '2024 대한민국 베스트브랜드 시상식',
      subtitle: '한방다이어트부문 대상 보미오라한의원',
    ),
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '빠르고 효과적인 다이어트를 위한 디톡스환',
      subtitle: '간편하고 빠르게 독소배출',
    ),
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '1:1 맞춤 전문 다이어트 솔루션',
      subtitle: '수많은 인플루언서의 선택! 보미 다이어트환',
    ),
    BannerItem(
      imageUrl: AppAssets.bomioraPinkLogo,
      title: '보미오라 프리미엄 케어',
      subtitle: '전문가가 함께하는 다이어트 여정',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerH = healthDp(context, 323.08);
    final borderW = healthDp(context, 1);
    final textPad = healthDp(context, 20);
    final titleFs = healthSp(context, 20);
    final subtitleFs = healthSp(context, 14);
    final titleSubtitleGap = healthDp(context, 8);
    final indicatorBottom = healthDp(context, 10);
    final dotSize = healthDp(context, 8);
    final dotMarginH = healthDp(context, 4);
    final shadowOff = healthDp(context, 1);
    final shadowBlur = healthDp(context, 3);

    return Container(
      height: bannerH,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF5A8D),
            width: borderW,
          ),
        ),
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return GestureDetector(
                onTap: () {
                  // 배너 탭 시 상품 상세 이동 — 필요 시 아래 주석 해제
                  // if (banner.productId != null) {
                  //   Navigator.pushNamed(
                  //     context,
                  //     '/product/${banner.productId}',
                  //   );
                  // }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(color: Colors.grey[300]!),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(textPad),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleFs,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(shadowOff, shadowOff),
                                    blurRadius: shadowBlur,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: titleSubtitleGap),
                            Text(
                              banner.subtitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: subtitleFs,
                                shadows: [
                                  Shadow(
                                    offset: Offset(shadowOff, shadowOff),
                                    blurRadius: shadowBlur,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 페이지 인디케이터
          Positioned(
            bottom: indicatorBottom,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: banners.asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () => _pageController.animateToPage(
                    entry.key,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    margin: EdgeInsets.symmetric(horizontal: dotMarginH),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == entry.key
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class BannerItem {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? productId;

  BannerItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.productId,
  });
}
