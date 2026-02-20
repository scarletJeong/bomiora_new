import 'package:flutter/material.dart';

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
      imageUrl: 'img/banner/mainPage1.png',
      title: '보미오라 다이어트',
      subtitle: '건강한 체중감량의 시작',
      productId: '1686290723',
    ),
    BannerItem(
      imageUrl: 'img/banner/mainPage2.png',
      title: '다이어트 왜 자꾸 실패할까요?',
      subtitle: '공중파, 종편 TV출연 몸짱 한의사 다이어트',
    ),
    BannerItem(
      imageUrl: 'img/banner/mainPage3.png',
      title: '다이어트환/디톡스환 특허 등록',
      subtitle: '정대진 대표원장이 연구 배합,개발 후 특허등록',
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
      height: 600,
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
                    if (banner.productId != null) {
                    // 상품 상세 페이지로 이동 (URL 업데이트)
                    Navigator.pushNamed(
                      context,
                      '/product/${banner.productId}',
                    );
                  } 
                },
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], // 임시 배경색
                    borderRadius: BorderRadius.circular(8),

                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          banner.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            alignment: Alignment.center,
                            child: Text('이미지 로드 실패: ${banner.imageUrl}'),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.35),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                ),
              );
            },
          ),
          // 페이지 인디케이터
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
