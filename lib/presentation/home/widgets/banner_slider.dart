import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/services/banner_service.dart';
import '../../common/widgets/app_network_image.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../shopping/widgets/product_banner_slider.dart'
    show kSharedBannerHeightBase;

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key, this.bannersFuture});

  /// 홈에서 우선 프리패치한 Future를 넘기면 중복 요청을 피함
  final Future<List<BannerModel>>? bannersFuture;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  int _currentIndex = 0;
  late PageController _pageController;
  late Future<List<BannerModel>> _bannersFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bannersFuture =
        widget.bannersFuture ?? BannerService.fetchMobileBanners();
  }

  @override
  void didUpdateWidget(covariant BannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannersFuture != null &&
        widget.bannersFuture != oldWidget.bannersFuture) {
      _bannersFuture = widget.bannersFuture!;
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _bannersFuture = BannerService.fetchMobileBanners();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerH = healthDp(context, kSharedBannerHeightBase);
    final borderW = healthDp(context, 1);
    final indicatorBottom = healthDp(context, 10);
    final dotSize = healthDp(context, 8);
    final dotMarginH = healthDp(context, 4);

    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        final banners = snapshot.data ?? const <BannerModel>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            banners.isEmpty) {
          return SizedBox(
            height: bannerH,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        if (_currentIndex >= banners.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentIndex = 0);
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
        }

        final hasMultiple = banners.length > 1;

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
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.unknown,
                  },
                ),
                child: PageView.builder(
                  controller: _pageController,
                  physics: hasMultiple
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    final imageUrl =
                        ImageUrlHelper.resolveSiteAssetUrl(banner.imageUrl);
                    return AppNetworkImage(
                      url: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: bannerH,
                      decodeHeightLogical: bannerH,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: Colors.grey[200]!,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (hasMultiple)
                Positioned(
                  bottom: indicatorBottom,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(banners.length, (index) {
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          margin: EdgeInsets.symmetric(horizontal: dotMarginH),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentIndex == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
