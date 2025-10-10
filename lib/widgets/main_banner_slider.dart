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
      imageUrl: 'assets/images/banners/mobile/m_banner00.jpg',
      title: '보미오라 다이어트',
      subtitle: '건강한 체중감량의 시작',
      link: '/shop/item.php?it_id=1686290723',
    ),
    BannerItem(
      imageUrl: 'assets/images/banners/mobile/m_banner01.jpg',
      title: '다이어트 왜 자꾸 실패할까요?',
      subtitle: '공중파, 종편 TV출연 몸짱 한의사 다이어트',
    ),
    BannerItem(
      imageUrl: 'https://via.placeholder.com/400x300/96CEB4/FFFFFF?text=Banner+3',
      title: '다이어트환/디톡스환 특허 등록',
      subtitle: '정대진 대표원장이 연구 배합,개발 후 특허등록',
    ),
    BannerItem(
      imageUrl: 'assets/images/banners/mobile/m_banner02.jpg',
      title: '2024 대한민국 베스트브랜드 시상식',
      subtitle: '한방다이어트부문 대상 보미오라한의원',
    ),
    BannerItem(
      imageUrl: 'assets/images/banners/mobile/m_banner03.jpg', 
      title: '빠르고 효과적인 다이어트를 위한 디톡스환',
      subtitle: '간편하고 빠르게 독소배출',
    ),
    BannerItem(
      imageUrl: 'assets/images/banners/mobile/m_banner04.jpg',
      title: '1:1 맞춤 전문 다이어트 솔루션',
      subtitle: '수많은 인플루언서의 선택! 보미 다이어트환',
    ),
    BannerItem(
      imageUrl: 'assets/images/banners/mobile/m_banner05.jpg',
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
                  if (banner.link != null) {
                    // 상품 페이지로 이동
                    print('Navigate to: ${banner.link}');
                  }
                },
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], // 임시 배경색
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Padding(
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
  final String? link;

  BannerItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.link,
  });
}
