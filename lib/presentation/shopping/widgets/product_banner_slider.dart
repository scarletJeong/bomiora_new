import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/services/banner_service.dart';
import '../../health/health_common/health_responsive_scale.dart';

class ProductBannerSlider extends StatefulWidget {
  /// 375 기준 배너 높이 — [healthDp]로 스케일.
  final double heightBase;

  /// `general` | 그 외(처방·비대면)
  final String? productKind;

  const ProductBannerSlider({
    super.key,
    this.heightBase = 190,
    this.productKind,
  });

  @override
  State<ProductBannerSlider> createState() => _ProductBannerSliderState();
}

class _ProductBannerSliderState extends State<ProductBannerSlider> {
  int _currentIndex = 0;
  late PageController _pageController;
  late Future<List<BannerModel>> _bannersFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadBanners();
  }

  @override
  void didUpdateWidget(covariant ProductBannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productKind != widget.productKind) {
      _loadBanners();
    }
  }

  void _loadBanners() {
    setState(() {
      _currentIndex = 0;
      _bannersFuture = BannerService.fetchListBanners(
        productKind: widget.productKind,
      );
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadBanners();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerH = healthDp(context, widget.heightBase);
    final borderW = healthDp(context, 3);
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
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
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
                    return Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: bannerH,
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
