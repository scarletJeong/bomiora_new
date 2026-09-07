import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/services/banner_service.dart';
import '../../common/widgets/app_network_image.dart';
import '../../health/health_common/health_responsive_scale.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider({
    super.key,
    this.bannersFuture,
    this.onPrimaryImageSettled,
  });

  /// 홈에서 우선 프리패치한 Future를 넘기면 중복 요청을 피함
  final Future<List<BannerModel>>? bannersFuture;

  /// 첫 배너(핑크) 표시 준비 시 1회
  final VoidCallback? onPrimaryImageSettled;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  static const Color _primaryBannerColor = Color(0xFFFF5A8D);

  /// 핑크 1장 + 서버 이미지 1장
  static const int _maxServerBanners = 1;

  int _currentIndex = 0;
  late PageController _pageController;
  late Future<List<BannerModel>> _bannersFuture;
  bool _primarySettledNotified = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bannersFuture =
        widget.bannersFuture ?? BannerService.fetchMobileBanners();
  }

  void _notifyPrimarySettled() {
    if (_primarySettledNotified) return;
    _primarySettledNotified = true;
    widget.onPrimaryImageSettled?.call();
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

  List<BannerModel> _serverBanners(List<BannerModel> apiBanners) {
    return apiBanners
        .where((b) => b.imageUrl.trim().isNotEmpty)
        .take(_maxServerBanners)
        .toList();
  }

  Widget _buildPinkPage(double bannerH) {
    return ColoredBox(
      color: _primaryBannerColor,
      child: SizedBox(
        width: double.infinity,
        height: bannerH,
      ),
    );
  }

  Widget _buildServerPage(
    BuildContext context,
    BannerModel banner,
    double bannerH,
  ) {
    final imageUrl = ImageUrlHelper.resolveSiteAssetUrl(banner.imageUrl);
    if (imageUrl.isEmpty) {
      return ColoredBox(
        color: Colors.grey[200]!,
        child: SizedBox(width: double.infinity, height: bannerH),
      );
    }

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
  }

  @override
  Widget build(BuildContext context) {
    final bannerH = healthDp(context, 220);
    final borderW = healthDp(context, 1);
    final indicatorBottom = healthDp(context, 10);
    final dotSize = healthDp(context, 8);
    final dotMarginH = healthDp(context, 4);

    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        final serverBanners = _serverBanners(
          snapshot.data ?? const <BannerModel>[],
        );
        final pageCount = 1 + serverBanners.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyPrimarySettled();
        });

        if (_currentIndex >= pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentIndex = 0);
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
        }

        final hasMultiple = pageCount > 1;

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
                  itemCount: pageCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildPinkPage(bannerH);
                    }
                    return _buildServerPage(
                      context,
                      serverBanners[index - 1],
                      bannerH,
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
                    children: List.generate(pageCount, (index) {
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
