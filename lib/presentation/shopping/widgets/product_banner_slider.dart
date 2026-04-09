import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';

class ProductBannerSlider extends StatefulWidget {
  const ProductBannerSlider({super.key});

  @override
  State<ProductBannerSlider> createState() => _ProductBannerSliderState();
}

class _ProductBannerSliderState extends State<ProductBannerSlider> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<_BannerItem> banners = [
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
      title: '보미오라 다이어트',
      subtitle: '건강한 체중감량의 시작',
      productId: '1686290723',
    ),
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
      title: '다이어트 왜 자꾸 실패할까요?',
      subtitle: '공중파, 종편 TV출연 몸짱 한의사 다이어트',
    ),
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
      title: '다이어트환/디톡스환 특허 등록',
      subtitle: '정대진 대표원장이 연구 배합,개발 후 특허등록',
    ),
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
      title: '2024 대한민국 베스트브랜드 시상식',
      subtitle: '한방다이어트부문 대상 보미오라한의원',
    ),
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
      title: '빠르고 효과적인 다이어트를 위한 디톡스환',
      subtitle: '간편하고 빠르게 독소배출',
    ),
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
      title: '1:1 맞춤 전문 다이어트 솔루션',
      subtitle: '수많은 인플루언서의 선택! 보미 다이어트환',
    ),
    _BannerItem(
      imageUrl: AppAssets.bomioraLogo,
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
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFFF5A8D),
            width: 3,
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
                  final productId = banner.productId;
                  if (productId == null) return;
                  Navigator.pushNamed(context, '/product/$productId');
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            ColoredBox(color: Colors.grey[300]!),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.45),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              banner.subtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
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
          Positioned(
            bottom: 10,
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
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
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

class _BannerItem {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String? productId;

  const _BannerItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.productId,
  });
}

